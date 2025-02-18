defmodule Lux.Agent.Companies.SignalHandler.DefaultImplementation do
  @moduledoc """
  Default implementation of company signal handler that uses LLM to:
  1. Analyze tasks and determine required tools
  2. Select appropriate tools for the task
  3. Execute tools in sequence and evaluate results
  """

  @behaviour Lux.Agent.Companies.SignalHandler

  alias Lux.LLM
  alias Lux.Schemas.Companies.ObjectiveSignal
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  require Logger

  def handle_signal(%Signal{schema_id: TaskSignal} = signal, context) do
    case signal.payload["type"] do
      "assignment" -> handle_task_assignment(signal, context)
      "status_update" -> handle_task_update(signal, context)
      _ -> {:error, :unsupported_task_type}
    end
  end

  def handle_signal(%Signal{schema_id: ObjectiveSignal} = signal, context) do
    case signal.payload["type"] do
      "evaluate" -> handle_objective_evaluation(signal, context)
      "status_update" -> handle_objective_update(signal, context)
      "completion" -> handle_objective_completion(signal, context)
      _ -> {:error, :unsupported_task_type}
    end
  end

  def handle_signal(_signal, _context) do
    {:error, :unsupported_schema}
  end

  @impl true
  def handle_task_assignment(%Signal{payload: payload} = signal, context) do
    Logger.info("Analyzing task: #{payload["title"]}")

    with {:ok, analysis} <- analyze_task(payload, context),
         {:ok, result} <- execute_task(analysis, context) do
      # Create success response
      {:ok,
       %Signal{
         id: Lux.UUID.generate(),
         schema_id: TaskSignal,
         payload: %{
           "type" => "completion",
           "task_id" => payload["task_id"],
           "objective_id" => payload["objective_id"],
           "title" => payload["title"],
           "status" => "completed",
           "progress" => 100,
           "result" => %{
             "success" => true,
             "output" => result
           }
         },
         recipient: signal.sender,
         metadata: %{
           "completed_at" => DateTime.to_iso8601(DateTime.utc_now())
         }
       }}
    else
      {:error, stage, reason} ->
        # Create failure response with details
        {:ok,
         %Signal{
           id: Lux.UUID.generate(),
           schema_id: TaskSignal,
           payload: %{
             "type" => "failure",
             "task_id" => payload["task_id"],
             "objective_id" => payload["objective_id"],
             "title" => payload["title"],
             "status" => "failed",
             "result" => %{
               "success" => false,
               "error" => "Failed at #{stage}: #{inspect(reason)}"
             }
           },
           recipient: signal.sender
         }}
    end
  end

  @impl true
  def handle_task_update(%Signal{payload: payload} = signal, _context) do
    # Create progress update response
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: TaskSignal,
       payload:
         Map.merge(payload, %{
           "type" => "status_update",
           "status" => "in_progress"
         }),
       recipient: signal.sender
     }}
  end

  @impl true
  def handle_objective_evaluation(%Signal{payload: payload} = signal, context) do
    # Evaluate objective progress and determine next steps
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: ObjectiveSignal,
       payload:
         Map.merge(payload, %{
           "type" => "evaluate",
           "evaluation" => %{
             "decision" => "continue",
             "next_step_index" => get_next_step_index(payload),
             "assigned_agent" => select_agent_for_step(payload, context),
             "reasoning" => "Objective evaluation completed successfully"
           }
         }),
       recipient: signal.sender
     }}
  end

  @impl true
  def handle_objective_update(%Signal{payload: payload} = signal, _context) do
    # Update objective progress and status
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: ObjectiveSignal,
       payload:
         Map.merge(payload, %{
           "type" => "status_update",
           "context" => %{
             "progress" => calculate_progress(payload)
           }
         }),
       recipient: signal.sender
     }}
  end

  @impl true
  def handle_objective_completion(%Signal{payload: payload} = signal, _context) do
    # Handle objective completion
    {:ok,
     %Signal{
       id: Lux.UUID.generate(),
       schema_id: ObjectiveSignal,
       payload:
         Map.merge(payload, %{
           "type" => "completion",
           "context" => %{
             "progress" => 100
           },
           "evaluation" => %{
             "decision" => "complete",
             "reasoning" => "All steps completed successfully"
           }
         }),
       recipient: signal.sender
     }}
  end

  # Private Functions

  defp analyze_task(payload, context) do
    prompt = """
    Analyze this task and determine the requirements:
    Title: #{payload["title"]}
    Description: #{payload["description"]}

    Consider:
    1. What type of task is this?
    2. What tools might be needed?
    3. What should the output look like?
    4. Are there any constraints to consider?
    5. What artifacts should be produced?

    Provide a structured analysis that includes:
    - Task type
    - Required capabilities
    - Expected outputs
    - Success criteria
    """

    # Let OpenAI handle the tool schema transformation
    tools = get_available_tools(context)

    case LLM.call(prompt, tools, %{structured_output: true}) do
      {:ok, %LLM.Response{structured_output: analysis}} ->
        {:ok, analysis}

      {:error, reason} ->
        {:error, :analysis, reason}
    end
  end

  defp execute_task(analysis, context) do
    prompt = """
    Given this task analysis:
    #{format_analysis(analysis)}

    Execute the task using the available tools.
    Determine:
    1. Which tools to use
    2. What parameters to provide
    3. How to combine the results
    """

    # Let OpenAI handle tool execution
    tools = get_available_tools(context)

    case LLM.call(prompt, tools, %{structured_output: true}) do
      {:ok, %LLM.Response{structured_output: result}} ->
        {:ok, result}

      {:error, reason} ->
        {:error, :execution, reason}
    end
  end

  defp format_analysis(analysis) do
    """
    Task Type: #{analysis.task_type}
    Required Capabilities: #{Enum.join(analysis.capabilities, ", ")}
    Expected Outputs: #{Enum.join(analysis.expected_outputs, ", ")}
    Success Criteria: #{Enum.join(analysis.success_criteria, ", ")}
    """
  end

  defp get_available_tools(context) do
    (context.beams || []) ++ (context.lenses || []) ++ (context.prisms || [])
  end

  defp get_next_step_index(%{"steps" => steps}) do
    # Find the index of the next pending step
    case Enum.find_index(steps, &(&1["status"] == "pending")) do
      # If no pending steps, return length (completion)
      nil -> length(steps)
      index -> index
    end
  end

  defp get_next_step_index(_), do: 0

  defp select_agent_for_step(
         %{"steps" => steps, "context" => %{"available_agents" => agents}},
         _context
       ) do
    case Enum.at(steps, get_next_step_index(%{"steps" => steps})) do
      %{"assigned_to" => agent_id} when not is_nil(agent_id) ->
        agent_id

      _ ->
        # Select first available agent if no assignment
        case agents do
          [%{"id" => id} | _] -> id
          _ -> nil
        end
    end
  end

  defp select_agent_for_step(_, _), do: nil

  defp calculate_progress(%{"steps" => steps}) do
    completed = Enum.count(steps, &(&1["status"] == "completed"))
    total = length(steps)

    case total do
      0 -> 0
      _ -> round(completed / total * 100)
    end
  end

  defp calculate_progress(_), do: 0
end

defmodule Lux.Agent.Companies.SignalHandler.DefaultImplementation do
  @moduledoc """
  Default implementation of company signal handler that uses LLM to:
  1. Analyze tasks and determine required tools
  2. Select appropriate tools for the task
  3. Execute tools in sequence and evaluate results
  """

  @behaviour Lux.Agent.Companies.SignalHandler

  alias Lux.LLM
  alias Lux.Schemas.Companies.PlanSignal
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  require Logger

  @impl true
  def handle_signal(%Signal{schema_id: TaskSignal} = signal, context) do
    case signal.payload["type"] do
      "assignment" -> handle_task_assignment(signal, context)
      "status_update" -> handle_task_update(signal, context)
      _ -> {:error, :unsupported_task_type}
    end
  end

  def handle_signal(%Signal{schema_id: PlanSignal} = signal, context) do
    case signal.payload["type"] do
      "evaluate" -> handle_plan_evaluation(signal, context)
      "status_update" -> handle_plan_update(signal, context)
      "completion" -> handle_plan_completion(signal, context)
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
  def handle_plan_evaluation(_signal, _context) do
    {:error, :not_implemented}
  end

  @impl true
  def handle_plan_update(_signal, _context) do
    {:error, :not_implemented}
  end

  @impl true
  def handle_plan_completion(_signal, _context) do
    {:error, :not_implemented}
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
end

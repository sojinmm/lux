defmodule Lux.Company.Runner do
  @moduledoc """
  Handles the execution of plans within a company.

  The runner is responsible for:
  - Validating plan inputs
  - Coordinating between agents to execute plan steps
  - Tracking plan progress
  - Delivering results
  """

  use GenServer

  alias Lux.Signal
  alias Lux.Signal.Router

  require Logger

  # Client API

  def start_link({company, opts}) do
    name = opts[:name] || name_for(company)
    GenServer.start_link(__MODULE__, {company, opts}, name: name)
  end

  @doc """
  Runs a plan with the given name and parameters.
  Returns {:ok, plan_id} if the plan was started successfully.
  """
  def run_plan(runner, plan_name, params) when is_atom(plan_name) do
    GenServer.call(runner, {:run_plan, plan_name, params})
  end

  @doc """
  Starts a plan without executing any steps.
  Returns {:ok, plan_id} on success, {:error, reason} on failure.
  """
  def start_plan(runner, plan_name, params) do
    GenServer.call(runner, {:start_plan, plan_name, params})
  end

  @doc """
  Gets the current state of a plan.
  Returns {:ok, plan_state} on success, {:error, reason} on failure.
  """
  def get_plan_state(runner, plan_id) do
    GenServer.call(runner, {:get_plan_state, plan_id})
  end

  @doc """
  Executes the next step in a plan.
  Returns {:ok, result} on success, {:error, reason} on failure.
  """
  def execute_next_step(runner, plan_id) do
    GenServer.call(runner, {:execute_next_step, plan_id})
  end

  # Server Callbacks

  @impl true
  def init({company, opts}) do
    Logger.info("Initializing Runner with company: #{inspect(company.name)}")
    Logger.debug("Company plans: #{inspect(Map.keys(company.plans))}")
    Logger.debug("Router: #{inspect(opts[:router])}, Hub: #{inspect(opts[:hub])}")

    {:ok,
     %{
       company: company,
       plans: %{},  # Initialize empty plans map for tracking plan states
       running_plans: %{},
       plan_results: %{},
       router: opts[:router],
       hub: opts[:hub],
       task_supervisor: opts[:task_supervisor] || Task.Supervisor
     }}
  end

  @impl true
  def handle_call({:run_plan, plan_name, params}, _from, state) do
    case Map.fetch(state.company.plans, plan_name) do
      {:ok, plan} ->
        case validate_plan_inputs(plan, params) do
          :ok ->
            plan_id = generate_plan_id()
            # Start plan execution
            {:ok, pid} = start_plan_execution(plan_id, plan, params, state)

            new_state =
              put_in(state, [:running_plans, plan_id], %{
                plan: plan,
                status: :running,
                progress: 0,
                pid: pid
              })

            {:reply, {:ok, plan_id}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      :error ->
        {:reply, {:error, "Plan not found"}, state}
    end
  end

  @impl true
  def handle_call({:plan_status, plan_id}, _from, state) do
    case Map.get(state.running_plans, plan_id) do
      nil -> {:reply, {:error, :not_found}, state}
      plan_state -> {:reply, {:ok, plan_state}, state}
    end
  end

  @impl true
  def handle_info({:plan_progress, plan_id, progress}, state) do
    new_state =
      update_in(state.running_plans[plan_id], fn plan_state ->
        %{plan_state | progress: progress}
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:plan_completed, plan_id, results}, state) do
    {_plan_state, running_plans} = Map.pop(state.running_plans, plan_id)

    new_state = %{
      state
      | running_plans: running_plans,
        plan_results: Map.put(state.plan_results, plan_id, results)
    }

    Logger.info("Plan #{plan_id} completed with results: #{inspect(results)}")
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:plan_failed, plan_id, error}, state) do
    {_plan_state, running_plans} = Map.pop(state.running_plans, plan_id)
    new_state = %{state | running_plans: running_plans}
    Logger.error("Plan #{plan_id} failed with error: #{inspect(error)}")
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:start_plan, plan_name, params}, _from, %{company: company} = state) do
    Logger.debug("Starting plan #{inspect(plan_name)} with params: #{inspect(params)}")

    case company.plans[plan_name] do
      nil ->
        Logger.warning("Plan #{inspect(plan_name)} not found in company plans")
        {:reply, {:error, :plan_not_found}, state}

      plan ->
        Logger.debug("Found plan: #{inspect(plan)}")
        # Validate inputs
        required_inputs = MapSet.new(plan.inputs)
        provided_inputs = MapSet.new(Map.keys(params))

        if MapSet.subset?(required_inputs, provided_inputs) do
          plan_id = Lux.UUID.generate()
          Logger.debug("Generated plan ID: #{plan_id}")

          plan_state = %{
            status: :initialized,
            params: params,
            plan: plan,
            current_step: 0,
            results: []
          }

          Logger.debug("Initializing plan state: #{inspect(plan_state)}")
          new_state = put_in(state.plans[plan_id], plan_state)
          {:reply, {:ok, plan_id}, new_state}
        else
          missing = MapSet.difference(required_inputs, provided_inputs)
          Logger.warning("Missing required inputs: #{inspect(missing)}")
          {:reply, {:error, {:missing_inputs, missing}}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_plan_state, plan_id}, _from, state) do
    Logger.debug("Getting state for plan #{inspect(plan_id)}")

    case state.plans[plan_id] do
      nil ->
        Logger.warning("Plan #{inspect(plan_id)} not found")
        {:reply, {:error, :not_found}, state}
      plan_state ->
        Logger.debug("Found plan state: #{inspect(plan_state)}")
        {:reply, {:ok, plan_state}, state}
    end
  end

  @impl true
  def handle_call({:execute_next_step, plan_id}, _from, state) do
    Logger.debug("Executing next step for plan #{inspect(plan_id)}")

    case state.plans[plan_id] do
      nil ->
        Logger.warning("Plan #{inspect(plan_id)} not found")
        {:reply, {:error, :no_plan}, state}

      %{status: :completed} = plan_state ->
        Logger.info("Attempted to execute step on completed plan #{plan_id}")
        {:reply, {:error, :plan_completed}, state}

      %{current_step: current_step, plan: plan} = plan_state when current_step >= length(plan.steps) ->
        Logger.info("Plan #{plan_id} completed all steps")
        new_plan_state = %{plan_state | status: :completed}
        new_state = put_in(state.plans[plan_id], new_plan_state)
        {:reply, {:complete, Enum.reverse(new_plan_state.results)}, new_state}

      plan_state ->
        step = Enum.at(plan_state.plan.steps, plan_state.current_step)
        Logger.debug("Executing step: #{inspect(step)}")

        case execute_step(step, plan_state.params, state.company, state.router, state.hub) do
          {:ok, result} ->
            Logger.debug("Step completed successfully: #{inspect(result)}")
            new_plan_state = %{plan_state |
              current_step: plan_state.current_step + 1,
              results: [result | plan_state.results]
            }
            new_state = put_in(state.plans[plan_id], new_plan_state)
            {:reply, {:ok, result}, new_state}

          error ->
            Logger.error("Step execution failed: #{inspect(error)}")
            {:reply, error, state}
        end
    end
  end

  # Private Functions

  defp start_plan_execution(plan_id, plan, params, state) do
    runner = self()

    Task.Supervisor.start_child(state.task_supervisor, fn ->
      try do
        # Execute plan steps sequentially
        results =
          execute_plan_steps(
            plan,
            params,
            state.company,
            runner,
            plan_id,
            state.router,
            state.hub
          )

        send(runner, {:plan_completed, plan_id, results})
      catch
        kind, error ->
          Logger.error("Plan execution failed: #{inspect({kind, error})}")
          send(runner, {:plan_failed, plan_id, error})
      end
    end)
  end

  defp execute_plan_steps(plan, params, company, runner, plan_id, router, hub) do
    Logger.debug("Starting plan execution: #{inspect(plan)}")
    Logger.debug("Router: #{inspect(router)}, Hub: #{inspect(hub)}")

    plan.steps
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, %{params: params, results: []}}, fn {step, index}, {:ok, acc} ->
      progress = trunc((index + 1) / length(plan.steps) * 100)
      send(runner, {:plan_progress, plan_id, progress})

      Logger.debug("Executing step #{index + 1}: #{inspect(step)}")
      case execute_step(step, acc, company, router, hub) do
        {:ok, new_acc} ->
          Logger.debug("Step #{index + 1} completed successfully")
          {:cont, {:ok, new_acc}}
        {:error, reason} ->
          Logger.error("Step #{index + 1} failed: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_step(step, acc, company, router, hub) do
    Logger.debug("Starting step execution: #{inspect(step)}")
    with {:ok, task} <- step |> parse_step(),
         {:ok, agent} <- find_capable_agent(task, company) do
      case agent.agent do
        nil ->
          {:error, {:missing_agent, "Role #{agent.name} has no agent assigned"}}
        _ ->
          case task |> delegate_task(agent, acc, router, hub) do
            {:ok, result} ->
              Logger.debug("Step completed with result: #{inspect(result)}")
              {:ok, %{acc | results: [result | acc.results]}}
            error ->
              Logger.error("Step failed: #{inspect(error)}")
              error
          end
      end
    else
      error ->
        Logger.error("Step failed: #{inspect(error)}")
        error
    end
  end

  defp parse_step(step) do
    # Remove step number prefix (e.g., "1. ")
    task =
      step
      |> String.split(". ", parts: 2)
      |> List.last()
      |> String.downcase()

    {:ok, task}
  end

  defp find_capable_agent(task, company) do
    # First try CEO if they have the required capability and an agent
    if can_handle_task?(company.ceo, task) and has_agent?(company.ceo) do
      {:ok, company.ceo}
    else
      # Then try other members
      case Enum.find(company.members, &(can_handle_task?(&1, task) and has_agent?(&1))) do
        nil -> {:error, "No agent found capable of handling: #{task}"}
        agent -> {:ok, agent}
      end
    end
  end

  defp has_agent?(%{agent: agent}) when not is_nil(agent), do: true
  defp has_agent?(_), do: false

  defp can_handle_task?(role, task) do
    Enum.any?(role.capabilities, fn capability ->
      String.contains?(task, String.downcase(capability))
    end)
  end

  defp delegate_task(task, %{id: agent_id, name: agent_name} = _agent, acc, router, hub)
       when not is_nil(agent_id) do
    Logger.debug("Delegating task to agent #{agent_name} (#{agent_id})")
    signal_id = Lux.UUID.generate()

    signal =
      %{
        id: signal_id,
        schema_id: Lux.Schemas.TaskSignal,
        payload: %{
          task: task,
          context: %{
            params: acc.params,
            results: acc.results || []
          },
          response_hub: hub
        },
        sender: "company_runner",
        recipient: agent_id
      }
      |> Signal.new()

    Logger.debug("Created signal: #{inspect(signal)}")
    router_opts = [router: router, hub: hub]
    Logger.debug("Router options: #{inspect(router_opts)}")

    with :ok <- signal_id |> Router.subscribe(router_opts),
         :ok <- signal |> Router.route(router_opts) do
      Logger.debug("Signal routed successfully")
      # Wait for both signal_delivered and response in any order
      case wait_for_messages(signal_id) do
        {:ok, response} ->
          Logger.debug("Received response: #{inspect(response)}")
          {:ok,
           %{
             task: task,
             agent: agent_name,
             status: :completed,
             result: response.context
           }}
        {:error, reason} ->
          Logger.error("Error waiting for response: #{reason}")
          {:error, reason}
      end
    end
  end

  defp wait_for_messages(signal_id, received \\ %{}) do
    if Map.has_key?(received, :delivered) and Map.has_key?(received, :response) do
      {:ok, received.response}
    else
      receive do
        {:signal_delivered, ^signal_id} ->
          wait_for_messages(signal_id, Map.put(received, :delivered, true))
        {:signal, %{payload: response}} ->
          wait_for_messages(signal_id, Map.put(received, :response, response))
      after
        :timer.seconds(5) ->
          error = {:error, {:agent_timeout, "Agent did not respond within 5 seconds"}}
          # Notify plan failure
          notify_plan_failure(error)
          error
      end
    end
  end

  defp notify_plan_failure(error) do
    case Process.get(:current_plan_id) do
      nil -> :ok
      plan_id -> send(self(), {:plan_failed, plan_id, error})
    end
  end

  defp delegate_task(_task, agent, _acc, _router, _hub) do
    {:error, "Agent does not have a valid ID: #{inspect(agent)}"}
  end

  defp validate_plan_inputs(plan, params) do
    required_inputs = MapSet.new(plan.inputs)
    provided_inputs = MapSet.new(Map.keys(params))

    missing = MapSet.difference(required_inputs, provided_inputs)
    extra = MapSet.difference(provided_inputs, required_inputs)

    cond do
      not MapSet.equal?(missing, MapSet.new()) ->
        {:error, "Missing required inputs: #{inspect(MapSet.to_list(missing))}"}

      not MapSet.equal?(extra, MapSet.new()) ->
        {:error, "Unexpected inputs provided: #{inspect(MapSet.to_list(extra))}"}

      true ->
        :ok
    end
  end

  defp generate_plan_id, do: Lux.UUID.generate()

  defp name_for(%{__struct__: Lux.Company} = company) do
    # Extract the module name from the company struct
    company_module = company.__struct__
    Module.concat(company_module, "Runner")
  end

  defp name_for(company_module) when is_atom(company_module) do
    Module.concat(company_module, "Runner")
  end

  defp execute_plan(plan_id, plan, params, company, router, hub) do
    Logger.debug("Executing plan #{inspect(plan)} with params #{inspect(params)}")
    Process.put(:current_plan_id, plan_id)

    case validate_plan_inputs(plan, params) do
      :ok ->
        acc = %{params: params, results: []}
        result = Enum.reduce_while(plan.steps, {:ok, acc}, fn step, {:ok, acc} ->
          case execute_step(step, company, acc, router, hub) do
            {:ok, new_acc} -> {:cont, {:ok, new_acc}}
            error -> {:halt, error}
          end
        end)

        Process.delete(:current_plan_id)
        result

      error ->
        Process.delete(:current_plan_id)
        error
    end
  end
end

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

  # Server Callbacks

  @impl true
  def init({company, opts}) do
    {:ok,
     %{
       company: company,
       # plan_id => %{plan: plan, status: status, progress: progress}
       running_plans: %{},
       # plan_id => results
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
    plan.steps
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, %{params: params, results: []}}, fn {step, index}, {:ok, acc} ->
      progress = trunc((index + 1) / length(plan.steps) * 100)
      send(runner, {:plan_progress, plan_id, progress})

      case execute_step(step, acc, company, router, hub) do
        {:ok, new_acc} -> {:cont, {:ok, new_acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_step(step, acc, company, router, hub) do
    with {:ok, task} <- parse_step(step),
         {:ok, agent} <- find_capable_agent(task, company),
         {:ok, result} <- delegate_task(task, agent, acc, router, hub) do
      {:ok, %{acc | results: [result | acc.results]}}
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
    # First try CEO if they have the required capability
    if can_handle_task?(company.ceo, task) do
      {:ok, company.ceo}
    else
      # Then try other members
      case Enum.find(company.members, &can_handle_task?(&1, task)) do
        nil -> {:error, "No agent found capable of handling: #{task}"}
        agent -> {:ok, agent}
      end
    end
  end

  defp can_handle_task?(role, task) do
    Enum.any?(role.capabilities, fn capability ->
      String.contains?(task, String.downcase(capability))
    end)
  end

  defp delegate_task(task, agent, acc, router, hub) do
    case agent do
      %{id: id} when not is_nil(id) ->
        signal_id = Lux.UUID.generate()

        signal =
          Signal.new(%{
            id: signal_id,
            schema_id: Lux.Schemas.TaskSignal,
            payload: %{
              task: task,
              context: acc
            },
            sender: "company_runner",
            recipient: id
          })

        opts = [router: router, hub: hub]

        with :ok <- Router.subscribe(signal_id, opts),
             :ok <- Router.route(signal, opts) do
          receive do
            {:signal_delivered, ^signal_id} ->
              # Wait for response
              receive do
                {:signal, %{id: response_id, payload: response}} when response_id != signal_id ->
                  {:ok,
                   %{
                     task: task,
                     agent: agent.name,
                     status: :completed,
                     result: response
                   }}
              after
                :timer.seconds(30) ->
                  {:error, "Timeout waiting for agent response"}
              end
          after
            :timer.seconds(5) ->
              {:error, "Timeout waiting for signal delivery"}
          end
        end

      _ ->
        {:error, "Agent does not have a valid ID"}
    end
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
end

defmodule Lux.Company.ExecutionEngine.Supervisor do
  @moduledoc """
  Supervisor for the Objective Execution Engine.

  This supervisor manages:
  1. A Registry for tracking objective processes
  2. A DynamicSupervisor for managing objective processes
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Logger.debug("Starting ExecutionEngine.Supervisor with name: #{inspect(name)}")
    Logger.debug("Supervisor start options: #{inspect(opts)}")
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Starts a new objective process under this supervisor.

  Returns `{:ok, pid}` if successful, `{:error, reason}` otherwise.
  """
  def start_objective(supervisor, objective, company_pid, input, objective_id \\ nil) do
    objective_id = objective_id || "objective_#{:erlang.unique_integer([:positive])}"
    Logger.debug("Starting objective process #{objective_id} under supervisor #{inspect(supervisor)}")
    Logger.debug("Objective details: #{inspect(objective)}")
    Logger.debug("Company PID: #{inspect(company_pid)}")
    Logger.debug("Input: #{inspect(input)}")

    registry_name = Module.concat(supervisor, Registry)
    supervisor_name = Module.concat(supervisor, ObjectiveSupervisor)

    Logger.debug("Using registry: #{inspect(registry_name)}")
    Logger.debug("Using supervisor: #{inspect(supervisor_name)}")

    # Check if registry exists
    case Process.whereis(registry_name) do
      nil ->
        Logger.error("Registry #{inspect(registry_name)} not found!")
        {:error, :registry_not_found}
      registry_pid ->
        Logger.debug("Found registry at #{inspect(registry_pid)}")

        child_spec = {
          Lux.Company.ExecutionEngine.ObjectiveProcess,
          objective_id: objective_id,
          objective: objective,
          company_pid: company_pid,
          input: input,
          registry: registry_name
        }

        Logger.debug("Starting child with spec: #{inspect(child_spec)}")

        case DynamicSupervisor.start_child(supervisor_name, child_spec) do
          {:ok, pid} ->
            Logger.info("Started objective process #{objective_id} with pid #{inspect(pid)}")
            # Verify registration
            case Registry.keys(registry_name, pid) do
              [] ->
                Logger.warning("Process started but not registered in registry!")
                {:error, :registration_failed}
              keys ->
                Logger.debug("Process registered with keys: #{inspect(keys)}")
                {:ok, pid}
            end

          {:error, reason} = error ->
            Logger.error("Failed to start objective process: #{inspect(reason)}")
            error
        end
    end
  end

  @doc """
  Stops an objective process managed by this supervisor.

  Returns `:ok` if successful, `{:error, reason}` otherwise.
  """
  def stop_objective(supervisor, objective_id) do
    registry_name = Module.concat(supervisor, Registry)
    supervisor_name = Module.concat(supervisor, ObjectiveSupervisor)

    Logger.debug("Stopping objective #{objective_id}")
    Logger.debug("Looking up in registry: #{inspect(registry_name)}")

    # Log all registry entries for debugging
    case Process.whereis(registry_name) do
      nil ->
        Logger.error("Registry #{inspect(registry_name)} not found!")
        {:error, :registry_not_found}
      _pid ->
        Logger.debug("Current registry entries: #{inspect(Registry.select(registry_name, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]))}")

        case Registry.lookup(registry_name, objective_id) do
          [{pid, _}] ->
            Logger.debug("Found process #{inspect(pid)}, terminating...")
            result = DynamicSupervisor.terminate_child(supervisor_name, pid)
            Logger.debug("Termination result: #{inspect(result)}")
            result

          [] ->
            Logger.warning("Process not found for objective #{objective_id}")
            {:error, :not_found}
        end
    end
  end

  @doc """
  Lists all running objective processes under this supervisor.

  Returns a list of objective IDs.
  """
  def list_objectives(supervisor) do
    registry_name = Module.concat(supervisor, Registry)
    Logger.debug("Listing objectives from registry: #{inspect(registry_name)}")

    case Process.whereis(registry_name) do
      nil ->
        Logger.error("Registry #{inspect(registry_name)} not found!")
        []
      _pid ->
        # Log all registry entries for debugging
        all_entries = Registry.select(registry_name, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
        Logger.debug("All registry entries: #{inspect(all_entries)}")

        objectives = Registry.select(registry_name, [{{:_, :"$1", :_}, [], [:"$1"]}])
        Logger.debug("Found objectives: #{inspect(objectives)}")
        objectives
    end
  end

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Logger.debug("Initializing supervisor #{inspect(name)}")
    Logger.debug("Initialization options: #{inspect(opts)}")

    children = [
      # Registry for tracking objective processes
      {Registry, keys: :unique, name: Module.concat(name, Registry)},

      # DynamicSupervisor for managing objective processes
      {DynamicSupervisor,
        strategy: :one_for_one,
        name: Module.concat(name, ObjectiveSupervisor)
      }
    ]

    Logger.debug("Starting children: #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_all)
  end
end

defmodule Lux.Company do
  @moduledoc """
  Defines the core company functionality and structure.
  A company is the highest-level organizational unit that coordinates agent-based workflows.
  """

  use GenServer

  alias Lux.Company.Roles

  require Logger

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          mission: String.t(),
          module: module(),
          ceo: map(),
          roles: [map()],
          objectives: [Lux.Company.Objective.t()],
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :mission,
    :module,
    :ceo,
    roles: [],
    objectives: [],
    metadata: %{}
  ]

  @doc """
  Starts a company with the given configuration.
  """
  def start_link(module, opts \\ []) do
    GenServer.start_link(__MODULE__, {module, opts})
  end

  @doc """
  Lists all roles in the company.
  """
  def list_roles(company) do
    GenServer.call(company, :list_roles)
  end

  @doc """
  Gets a specific role by ID.
  """
  def get_role(company, role_id) do
    GenServer.call(company, {:get_role, role_id})
  end

  @doc """
  Assigns an agent to a role.
  """
  def assign_agent(company, role_id, agent) do
    GenServer.call(company, {:assign_agent, role_id, agent})
  end

  @doc """
  Lists all objectives in the company.
  """
  def list_objectives(company) do
    GenServer.call(company, :list_objectives)
  end

  @doc """
  Gets a specific objective by ID.
  """
  def get_objective(company, objective_id) do
    GenServer.call(company, {:get_objective, objective_id})
  end

  @doc """
  Gets the status of an objective.
  """
  def get_objective_status(company, objective_id) do
    GenServer.call(company, {:get_objective_status, objective_id})
  end

  @doc """
  Gets the artifacts produced by an objective.
  """
  def get_objective_artifacts(company, objective_id) do
    GenServer.call(company, {:get_objective_artifacts, objective_id})
  end

  @doc """
  Assigns an agent to an objective.
  """
  def assign_agent_to_objective(company, objective_id, agent_id) do
    GenServer.call(company, {:assign_agent_to_objective, objective_id, agent_id})
  end

  @doc """
  Starts an objective.
  """
  def start_objective(company, objective_id) do
    GenServer.call(company, {:start_objective, objective_id})
  end

  @doc """
  Updates the progress of an objective.
  """
  def update_objective_progress(company, objective_id, progress) do
    GenServer.call(company, {:update_objective_progress, objective_id, progress})
  end

  @doc """
  Completes an objective.
  """
  def complete_objective(company, objective_id) do
    GenServer.call(company, {:complete_objective, objective_id})
  end

  @doc """
  Marks an objective as failed.
  """
  def fail_objective(company, objective_id, reason \\ nil) do
    GenServer.call(company, {:fail_objective, objective_id, reason})
  end

  @doc """
  Runs a company with the given configuration.
  This starts all necessary processes and initializes the company state.

  ## Options
  - `:router` - The signal router to use for agent communication (required)
  - `:hub` - The agent hub to use for agent management (required)
  - `:timeout` - Timeout for agent initialization (default: 30_000)
  """
  def run(company, opts \\ []) do
    router = Keyword.fetch!(opts, :router)
    hub = Keyword.fetch!(opts, :hub)
    timeout = Keyword.get(opts, :timeout, 30_000)

    with {:ok, _} <- validate_company(company),
         {:ok, _} <- validate_router(router),
         {:ok, _} <- validate_hub(hub) do
      # Start the company
      {:ok, pid} = start_link(company, opts)

      # Initialize roles and agents
      {:ok, _} = init_roles(pid, timeout)
      {:ok, _} = init_agents(pid, timeout)

      {:ok, pid}
    end
  end

  @doc """
  Runs an objective in the company.
  """
  def run_objective(company, objective_id, input \\ %{}) do
    GenServer.call(company, {:run_objective, objective_id, input})
  end

  # Server Callbacks

  @impl true
  def init({module, opts}) do
    Logger.info("Starting company: #{module.name()}")
    Logger.info("Mission: #{module.mission()}")
    Logger.info("\nCEO:")

    # Initialize CEO
    ceo = module.ceo()
    Logger.info("  - #{ceo.name} with capabilities: #{Enum.join(ceo.capabilities, ", ")}")
    Logger.info("  - Using agent: #{ceo.agent}")

    # Initialize members
    Logger.info("\nMembers:")

    members = module.members()

    Enum.each(members, fn member ->
      Logger.info("  - #{member.name} with capabilities: #{Enum.join(member.capabilities, ", ")}")
      Logger.info("    Using agent: #{member.agent}")
    end)

    {:ok,
     %{
       module: module,
       opts: opts,
       roles: %{},
       objectives: %{},
       artifacts: %{}
     }}
  end

  @impl true
  def handle_call(:list_roles, _from, state) do
    {:reply, {:ok, Map.values(state.roles)}, state}
  end

  def handle_call({:get_role, role_id}, _from, state) do
    case Map.get(state.roles, role_id) do
      nil -> {:reply, {:error, :not_found}, state}
      role -> {:reply, {:ok, role}, state}
    end
  end

  def handle_call({:assign_agent, role_id, agent}, _from, state) do
    case Map.get(state.roles, role_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      role ->
        updated_role = %{role | agent: agent}
        updated_roles = Map.put(state.roles, role_id, updated_role)
        {:reply, {:ok, updated_role}, %{state | roles: updated_roles}}
    end
  end

  def handle_call(:list_objectives, _from, state) do
    {:reply, {:ok, Map.values(state.objectives)}, state}
  end

  def handle_call({:get_objective, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil -> {:reply, {:error, :not_found}, state}
      objective -> {:reply, {:ok, objective}, state}
    end
  end

  def handle_call({:get_objective_status, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil -> {:reply, {:error, :not_found}, state}
      objective -> {:reply, {:ok, objective.status}, state}
    end
  end

  def handle_call({:get_objective_artifacts, objective_id}, _from, state) do
    case Map.get(state.artifacts, objective_id) do
      nil -> {:reply, {:error, :not_found}, state}
      artifacts -> {:reply, {:ok, artifacts}, state}
    end
  end

  def handle_call({:assign_agent_to_objective, objective_id, agent_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{objective | assigned_agent: agent_id}
        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:start_objective, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{objective | status: :in_progress, started_at: DateTime.utc_now()}
        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:update_objective_progress, objective_id, progress}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{objective | progress: progress}
        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:complete_objective, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{
          objective
          | status: :completed,
            completed_at: DateTime.utc_now(),
            progress: 100
        }

        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:fail_objective, objective_id, reason}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{
          objective
          | status: :failed,
            completed_at: DateTime.utc_now(),
            error: reason
        }

        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:run_objective, objective_id, input}, _from, state) do
    case validate_objective(objective_id, input, state) do
      {:ok, _objective} ->
        # Create a new objective instance
        objective_instance = %{
          id: Lux.UUID.generate(),
          objective_id: objective_id,
          input: input,
          status: :pending,
          progress: 0,
          started_at: nil,
          completed_at: nil,
          error: nil
        }

        # Store the objective instance
        updated_objectives =
          Map.put(state.objectives, objective_instance.id, objective_instance)

        # Start the objective
        case start_objective(self(), objective_instance.id) do
          {:ok, _} ->
            {:reply, {:ok, objective_instance.id}, %{state | objectives: updated_objectives}}

          error ->
            {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  # Private Functions

  defp validate_company(company) do
    cond do
      not function_exported?(company, :name, 0) ->
        {:error, :missing_name}

      not function_exported?(company, :mission, 0) ->
        {:error, :missing_mission}

      not function_exported?(company, :ceo, 0) ->
        {:error, :missing_ceo}

      not function_exported?(company, :members, 0) ->
        {:error, :missing_members}

      true ->
        {:ok, company}
    end
  end

  defp validate_router(router) do
    if function_exported?(router, :start_link, 1) do
      {:ok, router}
    else
      {:error, :invalid_router}
    end
  end

  defp validate_hub(hub) do
    if function_exported?(hub, :start_link, 1) do
      {:ok, hub}
    else
      {:error, :invalid_hub}
    end
  end

  defp validate_objective(objective_id, input, state) do
    case state.module.objectives() do
      objectives when is_list(objectives) ->
        case Enum.find(objectives, &(&1.id == objective_id)) do
          nil ->
            {:error, :objective_not_found}

          objective ->
            validate_objective_input(objective, input)
        end

      _ ->
        {:error, :invalid_objectives}
    end
  end

  defp validate_objective_input(objective, input) do
    # For now, just validate that required fields are present
    # In the future, we can add more sophisticated validation
    required_fields = objective.required_fields || []

    if Enum.all?(required_fields, &Map.has_key?(input, &1)) do
      {:ok, objective}
    else
      {:error, :invalid_input}
    end
  end

  defp init_roles(pid, _timeout) do
    # Initialize roles from the company module
    module = :sys.get_state(pid).module
    ceo = module.ceo()
    members = module.members()

    # Create the CEO role
    {:ok, _} =
      Roles.create(pid, %{
        id: Lux.UUID.generate(),
        name: ceo.name,
        type: :ceo,
        capabilities: ceo.capabilities,
        agent: ceo.agent
      })

    # Create member roles
    Enum.each(members, fn member ->
      {:ok, _} =
        Roles.create(pid, %{
          id: Lux.UUID.generate(),
          name: member.name,
          type: :member,
          capabilities: member.capabilities,
          agent: member.agent
        })
    end)

    {:ok, pid}
  end

  defp init_agents(pid, _timeout) do
    # Start agents for each role
    {:ok, roles} = list_roles(pid)

    Enum.each(roles, fn role ->
      {:ok, _} = assign_agent(pid, role.id, role.agent)
    end)

    {:ok, pid}
  end
end

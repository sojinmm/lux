defmodule Lux.Company do
  @moduledoc """
  Defines and manages companies with a CEO and custom roles.

  Companies are the highest-level organizational unit in Lux, consisting of:
  - A CEO with leadership capabilities
  - Members with specific capabilities defined by you
  - (Future: Contractors with specialized capabilities)

  ## Example

      # Define a company
      defmodule MyApp.Companies.ContentTeam do
        use Lux.Company.DSL

        company do
          name "Content Creation Team"
          mission "Create engaging content efficiently"

          # Every company has a CEO
          has_ceo "Content Director" do
            agent MyApp.Agents.ContentDirector  # Local agent implementation
            goal "Direct content creation and review"
            can "plan"
            can "review"
            can "approve"
          end

          # Group member roles together
          members do
            has_role "Lead Researcher" do
              # Remote agent reference with hub
              agent {"researcher-123", :research_hub}
              goal "Research and analyze topics"
              can "research"
              can "analyze"
              can "summarize"
            end

            has_role "Senior Writer" do
              agent MyApp.Agents.Writer  # Local agent implementation
              goal "Create and edit content"
              can "write"
              can "edit"
              can "draft"
            end
          end

          # Future: contractors do ... end
        end
      end

      # Run the company with hub configuration
      {:ok, pid} = Lux.Company.start_link(MyApp.Companies.ContentTeam,
        router: :signal_router,
        hub: :agent_hub
      )
  """

  use GenServer

  alias Lux.Company.Objective
  alias Lux.Company.Objectives
  alias Lux.Signal.Router

  require Logger

  @type role_type :: :ceo | :member | :contractor
  @type agent_ref :: module() | {String.t(), atom()}

  @type role :: %{
          type: role_type(),
          id: String.t(),
          name: String.t(),
          goal: String.t(),
          capabilities: [String.t()],
          agent: agent_ref() | nil,
          hub: atom() | nil
        }

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          mission: String.t(),
          module: module(),
          ceo: role(),
          roles: [role()],
          objectives: [Objective.t()],
          plans: map()
        }

  defstruct [
    :id,
    :name,
    :mission,
    :module,
    :ceo,
    roles: [],
    objectives: [],
    plans: %{}
  ]

  def start_link(module, opts \\ []) when is_atom(module) do
    company = module.__company__()
    name = company.module |> Module.split() |> List.last() |> String.to_atom()
    GenServer.start_link(__MODULE__, {company, opts}, name: name)
  end

  @impl true
  def init({company, opts}) do
    Logger.info("Starting company: #{company.name}")
    Logger.info("Mission: #{company.mission}")

    # Log CEO info
    Logger.info("\nCEO:")

    Logger.info(
      "  - #{company.ceo.name} with capabilities: #{Enum.join(company.ceo.capabilities, ", ")}"
    )

    if company.ceo.agent, do: Logger.info("  - Using agent: #{inspect(company.ceo.agent)}")

    # Log other roles
    Logger.info("\nMembers:")

    for role <- company.roles do
      Logger.info("  - #{role.name} with capabilities: #{Enum.join(role.capabilities, ", ")}")
      if role.agent, do: Logger.info("    Using agent: #{inspect(role.agent)}")
      if role.hub, do: Logger.info("    Via hub: #{inspect(role.hub)}")
    end

    {:ok, %{company: company, opts: opts}}
  end

  @doc """
  Gets the current state of the company.
  """
  def get_state(company) do
    GenServer.call(company, :get_state)
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

  ## Example
      {:ok, pid} = Lux.Company.run(MyApp.Companies.ContentTeam,
        router: :signal_router,
        hub: :agent_hub
      )
  """
  def run(module, opts \\ []) when is_atom(module) do
    # Validate required options
    router = Keyword.fetch!(opts, :router)
    hub = Keyword.fetch!(opts, :hub)
    timeout = Keyword.get(opts, :timeout, 30_000)

    with {:ok, pid} <- start_link(module, opts),
         :ok <- initialize_agents(pid, timeout),
         :ok <- start_objectives(pid) do
      {:ok, pid}
    end
  end

  @doc """
  Initializes all agents in the company.
  This ensures each agent is available and properly configured.
  """
  def initialize_agents(company, timeout \\ 30_000) do
    GenServer.call(company, :initialize_agents, timeout)
  end

  @doc """
  Starts all pending objectives that have assigned agents.
  """
  def start_objectives(company) do
    GenServer.call(company, :start_objectives)
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:list_roles, _from, %{company: company} = state) do
    roles = [company.ceo | company.roles]
    {:reply, {:ok, roles}, state}
  end

  def handle_call({:get_role, role_id}, _from, %{company: company} = state) do
    roles = [company.ceo | company.roles]

    case Enum.find(roles, &(&1.id == role_id)) do
      nil -> {:reply, {:error, :role_not_found}, state}
      role -> {:reply, {:ok, role}, state}
    end
  end

  def handle_call({:assign_agent, role_id, agent}, _from, %{company: company} = state) do
    roles = [company.ceo | company.roles]

    case Enum.find(roles, &(&1.id == role_id)) do
      nil ->
        {:reply, {:error, :role_not_found}, state}

      role ->
        {hub, agent_ref} =
          case agent do
            {id, hub} when is_binary(id) and is_atom(hub) -> {hub, agent}
            module when is_atom(module) -> {nil, module}
          end

        updated_role = %{role | agent: agent_ref, hub: hub}

        new_company =
          if role.type == :ceo do
            %{company | ceo: updated_role}
          else
            %{
              company
              | roles:
                  Enum.map(company.roles, fn r ->
                    if r.id == role_id, do: updated_role, else: r
                  end)
            }
          end

        {:reply, {:ok, updated_role}, %{state | company: new_company}}
    end
  end

  def handle_call(:list_objectives, _from, %{company: company} = state) do
    {:reply, {:ok, company.objectives}, state}
  end

  def handle_call({:get_objective, objective_id}, _from, %{company: company} = state) do
    case Enum.find(company.objectives, &(&1.id == objective_id)) do
      nil -> {:reply, {:error, :objective_not_found}, state}
      objective -> {:reply, {:ok, objective}, state}
    end
  end

  def handle_call({:get_objective_status, objective_id}, _from, %{company: company} = state) do
    case Enum.find(company.objectives, &(&1.id == objective_id)) do
      nil -> {:reply, {:error, :objective_not_found}, state}
      objective -> {:reply, {:ok, objective.status}, state}
    end
  end

  def handle_call(
        {:assign_agent_to_objective, objective_id, agent_id},
        _from,
        %{company: company} = state
      ) do
    with {:ok, objective} <- find_objective(company, objective_id),
         {:ok, _role} <- find_role_by_agent(company, agent_id) do
      if agent_id in objective.assigned_agents do
        {:reply, {:error, :already_assigned}, state}
      else
        updated_objective = %{objective | assigned_agents: [agent_id | objective.assigned_agents]}
        new_state = update_objective(state, updated_objective)
        {:reply, {:ok, updated_objective}, new_state}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:start_objective, objective_id}, _from, %{company: company} = state) do
    case find_objective(company, objective_id) do
      {:ok, objective} ->
        if objective.status == :pending do
          if objective.assigned_agents == [] do
            {:reply, {:error, :no_agents_assigned}, state}
          else
            updated_objective = %{
              objective
              | status: :in_progress,
                started_at: DateTime.utc_now()
            }

            new_state = update_objective(state, updated_objective)
            {:reply, {:ok, updated_objective}, new_state}
          end
        else
          {:reply, {:error, :invalid_status}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:update_objective_progress, objective_id, progress},
        _from,
        %{company: company} = state
      )
      when is_integer(progress) and progress >= 0 and progress <= 100 do
    case find_objective(company, objective_id) do
      {:ok, objective} ->
        if objective.status == :in_progress do
          updated_objective = %{objective | progress: progress}
          new_state = update_objective(state, updated_objective)
          {:reply, {:ok, updated_objective}, new_state}
        else
          {:reply, {:error, :invalid_status}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_objective_progress, _id, _progress}, _from, state) do
    {:reply, {:error, :invalid_progress}, state}
  end

  def handle_call({:complete_objective, objective_id}, _from, %{company: company} = state) do
    with {:ok, objective} <- find_objective(company, objective_id),
         {:ok, ceo} <- get_ceo_agent(company) do
      if objective.status == :in_progress do
        # Prepare context for CEO evaluation
        context = %{
          objective:
            Map.take(objective, [:name, :description, :success_criteria, :steps, :progress]),
          current_progress: objective.progress,
          success_criteria: objective.success_criteria,
          metadata: objective.metadata
        }

        # Send evaluation request to CEO
        case request_ceo_evaluation(ceo, context, state.opts) do
          {:ok, true} ->
            # CEO approved completion
            updated_objective = %{
              objective
              | status: :completed,
                progress: 100,
                completed_at: DateTime.utc_now(),
                metadata: Map.put(objective.metadata, :approved_by, ceo.id)
            }

            new_state = update_objective(state, updated_objective)
            {:reply, {:ok, updated_objective}, new_state}

          {:ok, false, reason} ->
            # CEO rejected completion
            updated_objective = %{
              objective
              | metadata: Map.put(objective.metadata, :completion_rejected_reason, reason)
            }

            new_state = update_objective(state, updated_objective)
            {:reply, {:error, {:completion_rejected, reason}}, new_state}

          {:error, reason} ->
            {:reply, {:error, {:ceo_evaluation_failed, reason}}, state}
        end
      else
        {:reply, {:error, :invalid_status}, state}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:fail_objective, objective_id, reason}, _from, %{company: company} = state) do
    case find_objective(company, objective_id) do
      {:ok, objective} ->
        if objective.status == :in_progress do
          metadata = Map.put(objective.metadata, :failure_reason, reason)

          updated_objective = %{
            objective
            | status: :failed,
              completed_at: DateTime.utc_now(),
              metadata: metadata
          }

          new_state = update_objective(state, updated_objective)
          {:reply, {:ok, updated_objective}, new_state}
        else
          {:reply, {:error, :invalid_status}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:initialize_agents, _from, %{company: company, opts: opts} = state) do
    router = Keyword.fetch!(opts, :router)
    hub = Keyword.fetch!(opts, :hub)

    # Initialize CEO first
    with :ok <- initialize_agent(company.ceo, router, hub) do
      # Then initialize other roles
      results = Enum.map(company.roles, &initialize_agent(&1, router, hub))

      if Enum.all?(results, &(&1 == :ok)) do
        {:reply, :ok, state}
      else
        {:reply, {:error, :agent_initialization_failed}, state}
      end
    end
  end

  def handle_call(:start_objectives, _from, %{company: company} = state) do
    results =
      Enum.map(company.objectives, fn objective ->
        if Objective.can_start?(objective) do
          case start_objective(company, objective.id) do
            {:ok, _} -> :ok
            _ -> :error
          end
        else
          :ok
        end
      end)

    if Enum.all?(results, &(&1 == :ok)) do
      {:reply, :ok, state}
    else
      {:reply, {:error, :objective_start_failed}, state}
    end
  end

  # Private Helpers

  defp find_objective(company, objective_id) do
    case Enum.find(company.objectives, &(&1.id == objective_id)) do
      nil -> {:error, :objective_not_found}
      objective -> {:ok, objective}
    end
  end

  defp find_role_by_agent(company, agent_id) do
    roles = [company.ceo | company.roles]

    case Enum.find(roles, &agent_matches?(&1, agent_id)) do
      nil -> {:error, :agent_not_found}
      role -> {:ok, role}
    end
  end

  defp agent_matches?(role, agent_id) do
    case role.agent do
      {^agent_id, _hub} -> true
      ^agent_id -> true
      _ -> false
    end
  end

  defp update_objective(state, updated_objective) do
    new_objectives =
      Enum.map(state.company.objectives, fn objective ->
        if objective.id == updated_objective.id, do: updated_objective, else: objective
      end)

    put_in(state.company.objectives, new_objectives)
  end

  defp get_ceo_agent(%{ceo: %{agent: agent_ref, hub: hub}} = _company)
       when not is_nil(agent_ref) do
    case agent_ref do
      {id, _hub} when is_binary(id) -> {:ok, %{id: id, hub: hub}}
      module when is_atom(module) -> {:ok, %{id: Atom.to_string(module), hub: hub}}
    end
  end

  defp get_ceo_agent(_), do: {:error, :no_ceo_agent}

  defp request_ceo_evaluation(%{id: ceo_id, hub: hub}, context, opts) do
    # Create a signal for the CEO to evaluate the objective
    signal = %{
      id: Lux.UUID.generate(),
      schema_id: Lux.Schemas.TaskSignal,
      payload: %{
        task: "evaluate_objective",
        context: context,
        response_hub: hub
      },
      recipient: ceo_id
    }

    router = Keyword.fetch!(opts, :router)

    # Subscribe to response first
    :ok = Router.subscribe(signal.id, router: router)

    # Then route the signal
    case Router.route(signal, router: router, hub: hub) do
      :ok ->
        # Wait for CEO's response
        receive do
          {:signal, response} when response.id == signal.id ->
            case response.payload do
              %{approved: true} -> {:ok, true}
              %{approved: false, reason: reason} -> {:ok, false, reason}
              _ -> {:error, :invalid_response}
            end
        after
          30_000 -> {:error, :timeout}
        end

      error ->
        error
    end
  end

  defp initialize_agent(%{agent: nil}, _router, _hub), do: :ok

  defp initialize_agent(%{agent: agent_ref, hub: agent_hub} = role, router, hub) do
    # Create initialization signal
    signal = %{
      id: Lux.UUID.generate(),
      schema_id: Lux.Schemas.InitSignal,
      payload: %{
        role: role.type,
        goal: role.goal,
        capabilities: role.capabilities
      },
      recipient: get_agent_id(agent_ref)
    }

    # Route initialization signal
    case Router.route(signal, router: router, hub: agent_hub || hub) do
      :ok ->
        # Wait for acknowledgment
        receive do
          {:signal, response} when response.id == signal.id ->
            case response.payload do
              %{status: :initialized} -> :ok
              _ -> {:error, :initialization_failed}
            end
        after
          5_000 -> {:error, :timeout}
        end

      error ->
        error
    end
  end

  defp get_agent_id({id, _hub}) when is_binary(id), do: id
  defp get_agent_id(module) when is_atom(module), do: Atom.to_string(module)
end

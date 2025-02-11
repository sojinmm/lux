defmodule Lux.Company do
  @moduledoc """
  Defines a company structure for coordinating agent-based workflows.

  Companies are the highest-level organizational unit in Lux, consisting of:
  - A CEO agent for coordination and decision making
  - Member agents with specific roles and capabilities
  - Plans that define workflows to be executed

  ## Role Management

  Companies support dynamic role management, allowing you to:
  - Define roles without agents (vacant roles)
  - Assign agents to roles at runtime
  - List and query role information
  - Run plans only when required roles have agents

  ### Example with Vacant Roles

      defmodule MyApp.Companies.BlogTeam do
        use Lux.Company

        company do
          name "Content Creation Lab"
          mission "Create high-quality content"

          has_ceo "Content Director" do
            goal "Direct content creation"
            can "plan"
            can "review"
            # No agent specified - vacant role
          end

          has_member "Writer" do
            goal "Create content"
            can "write"
            can "edit"
            # No agent specified - vacant role
          end
        end
      end

  ### Managing Roles

      # Start the company
      {:ok, pid} = Lux.Company.start_link(MyApp.Companies.BlogTeam)

      # List roles
      {:ok, [ceo, writer]} = Lux.Company.list_roles(MyApp.Companies.BlogTeam)

      # Assign agents
      {:ok, _} = Lux.Company.assign_agent(MyApp.Companies.BlogTeam, ceo.id, MyApp.Agents.CEO)
      {:ok, _} = Lux.Company.assign_agent(MyApp.Companies.BlogTeam, writer.id, MyApp.Agents.Writer)

  See the `role_management.md` guide for more details on role management.
  """

  use Supervisor
  use GenServer

  alias Lux.Company.Plan
  alias Lux.Company.Role

  defstruct [:id, :name, :mission, :ceo, :members, :plans]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          mission: String.t(),
          ceo: Role.t(),
          members: [Role.t()],
          plans: %{atom() => Plan.t()}
        }

  @doc """
  Starts a company supervisor.
  """
  def start_link(module, opts \\ []) when is_atom(module) do
    Supervisor.start_link(__MODULE__, {module, opts}, name: name_for_module(module, opts))
  end

  @doc """
  Runs a plan within the company context.
  """
  def run_plan(company, plan_name, params) when is_atom(plan_name) do
    GenServer.call(name_for_company(company), {:run_plan, plan_name, params})
  end

  @doc """
  Assigns an agent to a role in the company.
  The role is identified by its ID.
  The agent can be either a module (for local agents) or a {id, hub} tuple for remote agents.
  """
  def assign_agent(company, role_id, agent_spec) do
    GenServer.call(name_for_company(company), {:assign_agent, role_id, agent_spec})
  end

  @doc """
  Gets a role by its ID.
  """
  def get_role(company, role_id) do
    GenServer.call(name_for_company(company), {:get_role, role_id})
  end

  @doc """
  Lists all roles in the company.
  """
  def list_roles(company) do
    GenServer.call(name_for_company(company), :list_roles)
  end

  # Supervisor callbacks

  @impl true
  def init({module, opts}) do
    company = module.__company__()
    name = opts[:name] || module
    Logger.info("Initializing company #{inspect(name)} with #{length(company.members) + 1} roles")

    # Start the company state manager (this GenServer)
    {:ok, company_pid} = GenServer.start_link(__MODULE__, %{company: company}, name: name_for_state_manager(name))
    Logger.debug("Started company state manager with PID: #{inspect(company_pid)}")

    children = [
      # CEO supervisor
      {Lux.Company.CEOSupervisor, {company.ceo, opts}},
      # Member agents supervisor
      {Lux.Company.MemberSupervisor, {company.members, opts}},
      # Company runner for executing plans
      {Lux.Company.Runner, {company, opts}}
    ]

    Logger.info("Starting company supervisors and runner")
    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl true
  def init(state) when is_map(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:assign_agent, role_id, agent_spec}, _from, %{company: company} = state) do
    Logger.info("Assigning agent #{inspect(agent_spec)} to role #{inspect(role_id)}")

    # Find the role
    case find_role(company, role_id) do
      {:ok, role, path} ->
        Logger.debug("Found role #{inspect(role.name)} at path #{inspect(path)}")
        # Update the role with the new agent
        updated_role = %{role | agent: agent_spec}
        # Update the company state
        updated_company = update_in(company, path, fn _ -> updated_role end)
        Logger.info("Successfully assigned agent to role #{inspect(role.name)}")
        {:reply, {:ok, updated_role}, %{state | company: updated_company}}

      :error ->
        Logger.warn("Failed to assign agent - role #{inspect(role_id)} not found")
        {:reply, {:error, :role_not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_role, role_id}, _from, %{company: company} = state) do
    Logger.debug("Getting role with ID: #{inspect(role_id)}")
    case find_role(company, role_id) do
      {:ok, role, _path} ->
        Logger.debug("Found role: #{inspect(role.name)}")
        {:reply, {:ok, role}, state}
      :error ->
        Logger.warn("Role not found: #{inspect(role_id)}")
        {:reply, {:error, :role_not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_roles, _from, %{company: company} = state) do
    roles = [company.ceo | company.members]
    Logger.debug("Listing #{length(roles)} roles")
    {:reply, {:ok, roles}, state}
  end

  # Private helpers

  defp name_for_module(module, opts) do
    opts[:name] || Module.concat(module, "Supervisor")
  end

  defp name_for_company(company) when is_atom(company) do
    if Module.split(company) |> length() > 1 do
      # It's a module name
      Module.concat(company, "Supervisor")
    else
      # It's a registered name
      company
    end
  end

  defp name_for_state_manager(module_or_name) when is_atom(module_or_name) do
    Module.concat(module_or_name, "StateManager")
  end

  defmacro __using__(_opts) do
    quote do
      import Lux.Company.DSL

      Module.register_attribute(__MODULE__, :company_config, accumulate: false)
      @before_compile Lux.Company
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __company__ do
        @company_config
      end
    end
  end

  defp find_role(company, role_id) do
    Logger.debug("Searching for role with ID: #{inspect(role_id)}")
    cond do
      company.ceo.id == role_id ->
        Logger.debug("Found role in CEO position")
        {:ok, company.ceo, [:ceo]}

      member = Enum.find(company.members, & &1.id == role_id) ->
        index = Enum.find_index(company.members, & &1.id == role_id)
        Logger.debug("Found role in members list at index #{index}")
        {:ok, member, [:members, Access.at(index)]}

      true ->
        Logger.debug("Role not found")
        :error
    end
  end
end

defmodule Lux.Company.Role do
  @moduledoc """
  Defines a role within a company.

  A role represents a position in the company that can be filled by an agent.
  It includes:
  - The role type (CEO or member)
  - The role name and goal
  - The agent specification (local module or remote agent ID)
  - The capabilities the role provides
  - The hub where the agent can be found

  ## Examples

      # Local agent
      %Role{
        name: "Test CEO",
        agent: TestCEO,
        capabilities: ["plan", "review"]
      }

      # Remote agent
      %Role{
        name: "Remote Researcher",
        agent: {"researcher-123", RemoteHub},
        capabilities: ["research"]
      }
  """

  @type agent_spec ::
    module() |                    # Local agent module
    {String.t(), atom()}         # {agent_id, hub_name} pair

  @type t :: %__MODULE__{
    type: :ceo | :member,
    name: String.t(),
    id: String.t(),
    capabilities: [String.t()],
    goal: String.t() | nil,
    agent: agent_spec() | nil,    # How to find/create the agent
    hub: atom() | nil            # Defaults to company's local hub
  }

  defstruct [
    :type,
    :name,
    :id,
    :goal,
    :agent,
    :hub,
    capabilities: []
  ]

  @doc """
  Creates a new role with the given attributes.

  ## Examples

      iex> Role.new(%{
      ...>   type: :member,
      ...>   name: "Test Role",
      ...>   agent: TestAgent,
      ...>   capabilities: ["test"]
      ...> })
      %Role{
        type: :member,
        name: "Test Role",
        agent: TestAgent,
        capabilities: ["test"],
        id: "..." # Generated UUID
      }

      iex> Role.new(%{
      ...>   type: :member,
      ...>   name: "Remote Role",
      ...>   agent: {"agent-123", RemoteHub},
      ...>   capabilities: ["test"]
      ...> })
      %Role{
        type: :member,
        name: "Remote Role",
        agent: {"agent-123", RemoteHub},
        hub: RemoteHub,
        capabilities: ["test"],
        id: "..." # Generated UUID
      }
  """
  def new(attrs) when is_map(attrs) do
    role = struct!(__MODULE__, attrs)
    # Extract hub from remote agent spec if present
    hub = case role.agent do
      {_id, hub} -> hub
      _ -> role.hub
    end

    %{role |
      id: attrs[:id] || Lux.UUID.generate(),
      hub: hub
    }
  end

  @doc """
  Validates a role definition.

  ## Examples

      iex> Role.validate(role_with_local_agent)
      {:ok, role}

      iex> Role.validate(role_with_invalid_type)
      {:error, "Invalid role type"}
  """
  def validate(%__MODULE__{} = role) do
    with :ok <- validate_type(role.type),
         :ok <- validate_name(role.name),
         :ok <- validate_agent_spec(role.agent),
         :ok <- validate_capabilities(role.capabilities) do
      {:ok, role}
    end
  end

  # Private validation functions

  defp validate_type(type) when type in [:ceo, :member], do: :ok
  defp validate_type(_), do: {:error, "Invalid role type"}

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  defp validate_name(_), do: {:error, "Role name must be a non-empty string"}

  defp validate_agent_spec(nil), do: :ok
  defp validate_agent_spec(module) when is_atom(module) do
    # Only validate it's an atom, actual module existence check can be done at runtime
    if Atom.to_string(module) =~ ~r/^[A-Z]/, do: :ok, else: {:error, :invalid_agent_specification}
  end
  defp validate_agent_spec({id, hub}) when is_binary(id) and is_atom(hub), do: :ok
  defp validate_agent_spec(_), do: {:error, :invalid_agent_specification}

  defp validate_capabilities(capabilities) when is_list(capabilities) do
    if Enum.all?(capabilities, &is_binary/1) do
      :ok
    else
      {:error, "Capabilities must be strings"}
    end
  end
  defp validate_capabilities(_), do: {:error, "Invalid capabilities"}
end

defmodule Lux.Company.CEOSupervisor do
  use Supervisor

  def start_link(opts) do
    opts = Map.new(opts)
    Supervisor.start_link(__MODULE__, opts, name: name_for(opts.role))
  end

  def init(opts) do
    role = opts.role

    children = case role.agent do
      nil -> []  # No children if no agent assigned
      module when is_atom(module) -> [{module, Map.put(opts, :role, role)}]
      _ -> []  # No children for remote agents
    end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp name_for(role) do
    case role.agent do
      nil -> Module.concat(role.name |> String.replace(" ", "") |> String.to_atom(), "Supervisor")
      module when is_atom(module) -> Module.concat(module, "Supervisor")
      _ -> Module.concat(role.name |> String.replace(" ", "") |> String.to_atom(), "Supervisor")
    end
  end
end

defmodule Lux.Company.MemberSupervisor do
  use Supervisor

  def start_link(opts) do
    opts = Map.new(opts)
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    members = opts.members || []

    children = members
    |> Enum.filter(fn role ->
      case role.agent do
        nil -> false  # Skip roles without agents
        module when is_atom(module) -> true  # Include local agent modules
        _ -> false  # Skip remote agents
      end
    end)
    |> Enum.map(fn role ->
      {role.agent, Map.put(opts, :role, role)}
    end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end

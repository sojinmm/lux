defmodule Lux.Company.Role do
  @moduledoc """
  Defines a role within a company.

  A role represents a position in the company that can be filled by an agent.
  It includes:
  - The role type (CEO or member)
  - The role name and goal
  - The agent module that implements the role
  - The capabilities the role provides
  """

  @type t :: %__MODULE__{
          type: :ceo | :member,
          name: String.t(),
          goal: String.t() | nil,
          agent_module: module() | nil,
          capabilities: [String.t()]
        }

  defstruct [
    :type,
    :name,
    :goal,
    :agent_module,
    capabilities: []
  ]

  @doc """
  Creates a new role with the given attributes.
  """
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Validates a role definition.
  """
  def validate(%__MODULE__{} = role) do
    with :ok <- validate_type(role.type),
         :ok <- validate_name(role.name),
         :ok <- validate_agent_module(role.agent_module),
         :ok <- validate_capabilities(role.capabilities) do
      {:ok, role}
    end
  end

  # Private validation functions

  defp validate_type(type) when type in [:ceo, :member], do: :ok
  defp validate_type(_), do: {:error, "Invalid role type"}

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0, do: :ok
  defp validate_name(_), do: {:error, "Role name must be a non-empty string"}

  defp validate_agent_module(module) when is_atom(module), do: :ok
  defp validate_agent_module(nil), do: {:error, "Agent module is required"}
  defp validate_agent_module(_), do: {:error, "Invalid agent module"}

  defp validate_capabilities(capabilities) when is_list(capabilities) do
    if Enum.all?(capabilities, &is_binary/1) do
      :ok
    else
      {:error, "Capabilities must be strings"}
    end
  end

  defp validate_capabilities(_), do: {:error, "Invalid capabilities"}
end

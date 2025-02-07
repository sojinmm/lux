defmodule Lux.Company.Plan do
  @moduledoc """
  Defines an executable plan within a company.

  A plan represents a workflow that can be executed by the company's agents.
  It includes:
  - A unique name
  - Input field definitions
  - A sequence of steps to execute
  """

  @type t :: %__MODULE__{
          name: atom(),
          inputs: [String.t()],
          steps: [String.t()]
        }

  defstruct [
    :name,
    inputs: [],
    steps: []
  ]

  @doc """
  Creates a new plan with the given attributes.
  """
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Validates a plan definition.
  """
  def validate(%__MODULE__{} = plan) do
    with :ok <- validate_name(plan.name),
         :ok <- validate_inputs(plan.inputs),
         :ok <- validate_steps(plan.steps) do
      {:ok, plan}
    end
  end

  # Private validation functions

  defp validate_name(name) when is_atom(name), do: :ok
  defp validate_name(_), do: {:error, "Plan name must be an atom"}

  defp validate_inputs(inputs) when is_list(inputs) do
    if Enum.all?(inputs, &is_binary/1) do
      :ok
    else
      {:error, "Plan inputs must be strings"}
    end
  end

  defp validate_inputs(_), do: {:error, "Invalid plan inputs"}

  defp validate_steps([]), do: {:error, "Plan must have at least one step"}

  defp validate_steps(steps) when is_list(steps) do
    if Enum.all?(steps, &is_binary/1) do
      :ok
    else
      {:error, "Plan steps must be strings"}
    end
  end

  defp validate_steps(_), do: {:error, "Invalid plan steps"}
end

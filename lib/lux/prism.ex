defmodule Lux.Prism do
  @moduledoc """
  Modular, composable units of functionality for defining actions.

  Prisms are used to define actions that can be executed by agents.
  """
  use Lux.Types

  @typedoc """
  A schema is a map of key-value pairs that describe the structure of the data.
  """
  @type schema :: map()

  @typedoc """
  A handler is a function or a module that handles the data.
  """
  @type handler :: function() | mfa() | binary()

  @typedoc """
  A validator is a function or a module that validates the data.
  """
  @type validator :: function() | mfa() | binary()

  defstruct [
    :id,
    :name,
    :handler,
    :description,
    :examples,
    :input_schema,
    :output_schema,
    :schema
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          handler: handler(),
          description: nullable(String.t()),
          examples: nullable([String.t()]),
          input_schema: nullable(schema()),
          output_schema: nullable(schema()),
          schema: nullable(schema())
        }

  @doc """
  Creates a new prism from a map or keyword list.

  ## Examples:

  iex> Prism.new(%{id: "1", name: "test", handler: &String.split/2, description: "test", examples: ["test"]})
  %Prism{id: "1", name: "test", handler: &String.split/2, description: "test", examples: ["test"]}
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: attrs[:id] || "",
      name: attrs[:name] || "",
      handler: attrs[:handler] || nil,
      description: attrs[:description] || "",
      examples: attrs[:examples] || [],
      input_schema: attrs[:input_schema] || nil,
      output_schema: attrs[:output_schema] || nil,
      schema: attrs[:schema] || nil
    }
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  @doc """
  A handler is the function that will be called when the prism is executed.
  """
  @callback handler(input :: any(), context :: any()) :: {:ok, any()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      alias Lux.Prism
      @behaviour Lux.Prism

      def run(input, context \\ nil) do
        Lux.Prism.run(__MODULE__, input, context)
      end
    end
  end

  def run(schema, input, context \\ nil)

  def run(module, input, context) when is_atom(module) do
    module.handler(input, context)
  end

  def run(%__MODULE__{handler: handler}, input, context) do
    handler.(input, context)
  end

  @optional_callbacks []
end

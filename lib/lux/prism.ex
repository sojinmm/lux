defmodule Lux.Prism do
  @moduledoc """
  Modular, composable units of functionality for defining actions.

  Prisms are used to define actions that can be executed by agents and are defined as records.


  """
  use Lux.Types
  require Record

  Record.defrecord(:prism, __MODULE__, [
    :description,
    :examples,
    :handler,
    :id,
    :input_schema,
    :name,
    :output_schema,
    :schema
  ])

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

  @type t ::
          record(:prism,
            id: String.t(),
            name: String.t(),
            handler: function() | mfa() | binary(),
            description: nullable(String.t()),
            examples: nullable([String.t()]),
            input_schema: nullable(schema()),
            output_schema: nullable(schema())
          )

  @doc """
  Creates a new prism from a map or keyword list.

  ## Examples:

  iex> Prism.new(%{id: "1", name: "test", handler: &String.split/2, description: "test", examples: ["test"]})
  prism(id: "1", name: "test", handler: &String.split/2, description: "test", examples: ["test"])
  """
  @spec new(map() | keyword()) :: t()
  def new(atrs) when is_map(atrs) do
    prism(
      id: atrs[:id] || "",
      name: atrs[:name] || "",
      handler: atrs[:handler] || nil,
      description: atrs[:description] || "",
      examples: atrs[:examples] || [],
      input_schema: atrs[:input_schema] || nil,
      output_schema: atrs[:output_schema] || nil
    )
  end

  def new(atrs) when is_list(atrs) do
    atrs |> Map.new() |> new()
  end

  @doc """
  A handler is the function that will be called when the prism is executed.
  """
  @callback handler(input :: any(), context :: any()) :: {:ok, any()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      require Lux.Prism
      import Lux.Prism

      @behaviour Lux.Prism

      # Later let's use this to setup the Prism via use...
      # @name opts[:name] || __MODULE__
      # @description opts[:description] || ""
      # @input_schema opts[:input_schema] || %{}
      # @output_schema opts[:output_schema] || %{}
      # @handler opts[:handler] || nil
      # @examples opts[:examples] || []

      # def config do
      #   # extrac the config at compile time
      #   # return the prism
      # end

      def run(input, context \\ nil) do
        Lux.Prism.run(__MODULE__, input, context)
      end
    end
  end

  def run(schema, input, context \\ nil)

  def run(module, input, context) when is_atom(module) do
    module.handler(input, context)
  end

  def run(prism(handler: handler), input, context) do
    handler.(input, context)
  end

  @optional_callbacks []
end

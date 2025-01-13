defmodule Lux.Signal do
  @moduledoc """
  Defines the core Signal struct and behavior for the Lux framework.

  A Signal represents a discrete unit of information that can be processed by agents
  and workflows. Each Signal has an associated schema that defines its structure and
  validation rules.
  """

  @enforce_keys [:id, :schema_id, :content]
  defstruct [:id, :schema_id, :content]

  @type t :: %__MODULE__{
          id: String.t(),
          schema_id: String.t(),
          content: map()
        }

  @doc """
  Creates a new Signal struct from the given attributes.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Defines the behavior for Signal modules.
  """
  defmacro __using__(opts) do
    schema_module = Keyword.fetch!(opts, :schema)

    quote do
      @schema unquote(schema_module)

      def new(content) do
        with {:ok, validated} <- validate(content),
             {:ok, transformed} <- transform(validated) do
          signal =
            Lux.Signal.new(%{
              id: Lux.UUID.generate(),
              schema_id: schema_id(),
              content: transformed
            })

          {:ok, signal}
        end
      end

      def validate(content), do: {:ok, content}
      def transform(content), do: {:ok, content}

      def schema, do: @schema.schema()
      def schema_id, do: @schema.schema_id()

      defoverridable validate: 1, transform: 1
    end
  end
end

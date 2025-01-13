defmodule Lux.SignalSchema do
  @moduledoc """
  Defines the behavior and macros for creating Signal schemas.

  Signal schemas define the structure and validation rules for Signal content.
  They are used to ensure that Signals conform to expected formats and can be
  properly processed by agents and workflows.
  """

  alias Lux.UUID

  @type compatibility :: :full | :backward | :forward | :none
  @type format :: :json | :yaml | :binary | :text
  @type status :: :draft | :active | :deprecated | :retired

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          schema: map(),
          created_at: DateTime.t(),
          created_by: String.t(),
          description: String.t() | nil,
          tags: [String.t()],
          compatibility: compatibility(),
          status: status(),
          format: format(),
          reference: String.t() | nil
        }

  defstruct [
    :id,
    :name,
    :version,
    :schema,
    :created_at,
    :created_by,
    :description,
    tags: [],
    compatibility: :full,
    status: :draft,
    format: :json,
    reference: nil
  ]

  @doc """
  Creates a new schema struct from the given attributes.
  """
  def new(attrs) when is_map(attrs) do
    attrs =
      Map.put_new_lazy(attrs, :id, &UUID.generate/0)
      |> Map.put_new_lazy(:created_at, &DateTime.utc_now/0)

    struct!(__MODULE__, attrs)
  end

  @doc """
  Defines a new Signal schema.

  ## Options
    * `:name` - The name of the schema. Defaults to the module name if not provided.
    * `:version` - The schema version. Defaults to "1.0.0".
    * `:schema` - Required. The JSON Schema definition for the Signal content.
    * `:description` - Optional description of the schema.
    * `:tags` - Optional list of tags for categorization.
    * `:compatibility` - Schema compatibility level (:full, :backward, :forward, :none).
    * `:status` - Schema status (:draft, :active, :deprecated, :retired).
    * `:format` - Data format (:json, :yaml, :binary, :text).
    * `:reference` - Optional reference to external schema documentation.
  """
  defmacro __using__(opts) do
    quote do
      @schema_name unquote(opts[:name])
      @schema_description unquote(opts[:description])
      @schema_version unquote(opts[:version])
      @schema_tags unquote(opts[:tags])
      @schema_compatibility unquote(opts[:compatibility])
      @schema_format unquote(opts[:format])

      @schema_struct %Lux.SignalSchema{
        id: UUID.generate(),
        name: @schema_name || __MODULE__ |> Module.split() |> List.last(),
        description: @schema_description || nil,
        version: @schema_version || nil,
        tags: @schema_tags || [],
        compatibility: @schema_compatibility || :full,
        format: @schema_format || :json,
        schema: Lux.SignalSchema.normalize_schema(unquote(opts)[:schema])
      }

      def name, do: @schema_struct.name
      def schema, do: @schema_struct.schema
      def schema_id, do: @schema_struct.id
      def view, do: @schema_struct
    end
  end

  def normalize_schema(%{type: type, properties: {:%{}, _, props}, required: required}) do
    %{
      type: type,
      properties: props |> Enum.map(fn {k, v} -> {k, Enum.into(v, %{})} end) |> Enum.into(%{}),
      required: required
    }
  end

  def normalize_schema(%{type: type, properties: props} = schema) do
    %{
      type: type,
      properties: props,
      required: Map.get(schema, :required, [])
    }
  end

  def normalize_schema(%{type: type}) do
    %{
      type: type,
      properties: %{},
      required: []
    }
  end
end

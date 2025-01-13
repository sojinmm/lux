defmodule Lux.SignalSchemaTest do
  use ExUnit.Case, async: true
  alias Lux.SignalSchema

  describe "new/1" do
    test "creates a schema from a map" do
      attrs = %{
        name: "test_schema",
        description: "Test schema",
        version: "1.0.0",
        schema: %{type: :object, properties: %{name: %{type: :string}}}
      }

      schema = SignalSchema.new(attrs)

      assert %SignalSchema{} = schema
      assert schema.name == "test_schema"
      assert schema.description == "Test schema"
      assert schema.version == "1.0.0"
      assert schema.schema == %{type: :object, properties: %{name: %{type: :string}}}
    end
  end

  describe "when using SignalSchema" do
    test "creates a schema with declarative attributes" do
      defmodule ChatMessageSchema do
        use Lux.SignalSchema,
          name: "chat_message",
          description: "Basic chat message schema",
          version: "1.0.0",
          schema: %{
            type: :object,
            properties: %{
              message: %{type: :string},
              from: %{type: :string},
              to: %{type: :string}
            },
            required: ["message", "from", "to"]
          },
          tags: ["chat", "communication"],
          compatibility: :full,
          format: :json
      end

      schema_definition = ChatMessageSchema.view()
      schema = schema_definition.schema

      assert %{
               type: :object,
               properties: %{
                 message: %{type: :string},
                 from: %{type: :string},
                 to: %{type: :string}
               },
               required: ["message", "from", "to"]
             } = schema

      assert schema_definition.name == "chat_message"
      assert schema_definition.description == "Basic chat message schema"
      assert schema_definition.version == "1.0.0"
      assert schema_definition.tags == ["chat", "communication"]
      assert schema_definition.compatibility == :full
      assert schema_definition.format == :json
    end

    test "uses module name as default name" do
      defmodule DefaultNameSchema do
        use Lux.SignalSchema,
          schema: %{type: :object}
      end

      schema = DefaultNameSchema.view()
      assert schema.name == "DefaultNameSchema"
      assert schema.id == DefaultNameSchema.schema_id()
      assert schema.schema == %{type: :object, properties: %{}, required: []}
      assert schema.description == nil
      assert schema.version == nil
      assert schema.tags == []
      assert schema.compatibility == :full
      assert schema.format == :json
    end

    test "provides schema_id helper" do
      defmodule SchemaWithId do
        use Lux.SignalSchema,
          schema: %{type: :object}
      end

      assert is_binary(SchemaWithId.schema_id())
      assert SchemaWithId.schema_id() == SchemaWithId.view().id
    end
  end
end

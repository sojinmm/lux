defmodule Lux.SignalTest do
  use ExUnit.Case, async: true
  alias Lux.Signal

  describe "new/1" do
    test "creates a signal from a map" do
      attrs = %{
        id: "test-1",
        schema_id: "schema-1",
        content: %{message: "Hello"},
        metadata: %{created_at: "2024-01-01"},
        sender: "agent-1",
        target: "agent-2"
      }

      signal = Signal.new(attrs)

      assert %Signal{} = signal
      assert signal.id == "test-1"
      assert signal.schema_id == "schema-1"
      assert signal.content == %{message: "Hello"}
      assert signal.metadata == %{created_at: "2024-01-01"}
      assert signal.sender == "agent-1"
      assert signal.target == "agent-2"
    end

    test "initializes empty metadata when not provided" do
      attrs = %{
        id: "test-1",
        schema_id: "schema-1",
        content: %{message: "Hello"}
      }

      signal = Signal.new(attrs)
      assert signal.metadata == %{}
      assert signal.sender == nil
      assert signal.target == nil
    end
  end

  describe "when using Signal" do
    defmodule TestSchema do
      use Lux.SignalSchema,
        name: "test_schema",
        schema: %{
          type: :object,
          properties: %{
            message: %{type: :string}
          }
        }
    end

    test "creates a signal with schema reference" do
      defmodule BasicSignal do
        use Lux.Signal,
          schema: TestSchema
      end

      {:ok, signal} = BasicSignal.new(%{message: "Hello"})

      assert %Signal{} = signal
      assert is_binary(signal.id)
      assert signal.schema_id == TestSchema.schema_id()
      assert signal.content == %{message: "Hello"}
      assert signal.metadata == %{}
      assert signal.sender == nil
      assert signal.target == nil
    end

    test "creates a signal with sender and target" do
      defmodule RoutedSignal do
        use Lux.Signal,
          schema: TestSchema

        def transform(content) do
          {:ok, Map.put(content, :message, String.upcase(content.message))}
        end

        def extract_metadata(_content) do
          {:ok, %{sender: "agent-1", target: "agent-2"}}
        end
      end

      {:ok, signal} = RoutedSignal.new(%{message: "hello"})
      assert signal.content.message == "HELLO"
      assert signal.sender == "agent-1"
      assert signal.target == "agent-2"
    end

    test "supports content validation" do
      defmodule ValidatedSignal do
        use Lux.Signal,
          schema: TestSchema

        def validate(content) do
          if is_map(content) and Map.has_key?(content, :message) do
            {:ok, content}
          else
            {:error, "Invalid content"}
          end
        end
      end

      assert {:ok, %Signal{}} = ValidatedSignal.new(%{message: "Valid"})
      assert {:error, "Invalid content"} = ValidatedSignal.new(%{wrong: "Invalid"})
    end

    test "supports content transformation" do
      defmodule TransformedSignal do
        use Lux.Signal,
          schema: TestSchema

        def transform(content) do
          {:ok, Map.update!(content, :message, &String.upcase/1)}
        end
      end

      {:ok, signal} = TransformedSignal.new(%{message: "hello"})
      assert signal.content.message == "HELLO"
    end

    test "supports metadata extraction" do
      defmodule MetadataSignal do
        use Lux.Signal,
          schema: TestSchema

        def extract_metadata(_content) do
          {:ok,
           %{
             created_at: DateTime.utc_now(),
             version: 1,
             trace_id: Lux.UUID.generate()
           }}
        end
      end

      {:ok, signal} = MetadataSignal.new(%{message: "Hello"})
      assert %{created_at: %DateTime{}, version: 1} = signal.metadata
      assert is_binary(signal.metadata.trace_id)
    end

    test "provides schema helpers" do
      defmodule SignalWithHelpers do
        use Lux.Signal,
          schema: TestSchema
      end

      assert SignalWithHelpers.schema() == TestSchema.schema()
      assert SignalWithHelpers.schema_id() == TestSchema.schema_id()
    end

    test "chains validation, transformation, and metadata extraction" do
      defmodule ChainedSignal do
        use Lux.Signal,
          schema: TestSchema

        def validate(%{message: message} = content) when is_binary(message) do
          {:ok, content}
        end

        def validate(_), do: {:error, "Invalid message"}

        def transform(content) do
          {:ok, Map.update!(content, :message, &"#{&1}!")}
        end

        def extract_metadata(content) do
          {:ok,
           %{
             message_length: String.length(content.message),
             processed_at: DateTime.utc_now()
           }}
        end
      end

      assert {:ok, signal} = ChainedSignal.new(%{message: "Hi"})
      assert signal.content.message == "Hi!"
      assert signal.metadata.message_length == 3
      assert %DateTime{} = signal.metadata.processed_at
      assert {:error, "Invalid message"} = ChainedSignal.new(%{message: 123})
    end
  end
end

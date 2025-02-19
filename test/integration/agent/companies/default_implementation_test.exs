defmodule Lux.Integration.Agent.Companies.DefaultImplementationTest do
  use IntegrationCase, async: true

  alias Lux.Agent.Companies.SignalHandler.DefaultImplementation
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  # Test tools that perform real operations
  defmodule SearchPrism do
    @moduledoc false
    use Lux.Prism,
      name: "SearchPrism",
      description: "Searches for information in a given text",
      input_schema: %{
        type: "object",
        properties: %{
          "query" => %{
            type: "string",
            description: "The search query"
          },
          "text" => %{
            type: "string",
            description: "The text to search in"
          }
        },
        required: ["query", "text"]
      },
      capabilities: ["search", "analyze"]

    def handler(%{"query" => query, "text" => text}, _context) do
      if String.contains?(String.downcase(text), String.downcase(query)) do
        {:ok,
         %{
           found: true,
           matches: [text]
         }}
      else
        {:ok,
         %{
           found: false,
           matches: []
         }}
      end
    end
  end

  defmodule SummarizeLens do
    @moduledoc false
    use Lux.Lens,
      name: "SummarizeLens",
      description: "Summarizes a given text",
      schema: %{
        type: "object",
        properties: %{
          "text" => %{
            type: "string",
            description: "The text to summarize"
          },
          "max_length" => %{
            type: "integer",
            description: "Maximum length of the summary",
            default: 100
          }
        },
        required: ["text"]
      },
      capabilities: ["summarize", "analyze"]

    def call(%{"text" => text, "max_length" => max_length}, _context) do
      summary = String.slice(text, 0, max_length)
      {:ok, %{summary: summary}}
    end
  end

  describe "task execution with real LLM" do
    setup do
      context = %{
        beams: [],
        lenses: [SummarizeLens],
        prisms: [SearchPrism]
      }

      text = """
      The quick brown fox jumps over the lazy dog.
      This pangram contains every letter of the English alphabet.
      It is often used for testing fonts and keyboards.
      """

      signal = %Signal{
        id: "test-1",
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => "task-1",
          "objective_id" => "obj-1",
          "title" => "Analyze Text",
          "description" => "Search for 'fox' in the text and provide a summary.",
          "context" => %{
            "text" => text
          }
        },
        sender: "sender-1"
      }

      %{context: context, signal: signal}
    end

    test "executes task with real tools", %{context: context, signal: signal} do
      assert {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "completion"
      assert response.payload["status"] == "completed"
      assert response.payload["result"]["success"] == true

      # Verify the result contains both search and summary
      result = response.payload["result"]["output"]
      assert is_map(result)
      assert Map.has_key?(result, :search) or Map.has_key?(result, "search")
      assert Map.has_key?(result, :summary) or Map.has_key?(result, "summary")
    end

    @tag :integration
    test "handles task with unknown requirements gracefully", %{context: context, signal: signal} do
      signal = put_in(signal.payload["description"], "Do something impossible")

      assert {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "failure"
      assert response.payload["status"] == "failed"
      assert response.payload["result"]["success"] == false
    end
  end
end

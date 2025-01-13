# Prisms Guide

Prisms are modular units of functionality that can be composed into workflows. They provide a way to encapsulate business logic, transformations, and integrations into reusable components.

## Overview

A Prism consists of:
- A unique identifier
- Input and output schemas
- A handler function
- Optional configuration and metadata

## Creating a Prism

Here's a basic example of a Prism:

```elixir
defmodule MyApp.Prisms.TextAnalysis do
  use Lux.Prism,
    name: "Text Analysis",
    description: "Analyzes text for sentiment and key phrases",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Text to analyze"},
        language: %{type: :string, description: "ISO language code"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sentiment: %{
          type: :string,
          enum: ["positive", "negative", "neutral"]
        },
        confidence: %{type: :number},
        key_phrases: %{
          type: :array,
          items: %{type: :string}
        }
      },
      required: ["sentiment", "confidence"]
    }

  def handler(%{text: text, language: lang}, _ctx) do
    # Implementation
    {:ok, %{
      sentiment: "positive",
      confidence: 0.95,
      key_phrases: ["great", "awesome"]
    }}
  end
end
```

## Using Prisms

Prisms can be used directly or composed into Beams:

```elixir
# Direct usage
{:ok, result} = MyApp.Prisms.TextAnalysis.run(%{
  text: "Great product, highly recommended!",
  language: "en"
})

# Access results
result.sentiment    # "positive"
result.confidence   # 0.95
result.key_phrases  # ["great", "awesome"]
```

## Prism Types

### Transformation Prisms
Transform data from one format to another:

```elixir
defmodule MyApp.Prisms.DataTransformation do
  use Lux.Prism,
    name: "Data Transformer",
    description: "Transforms data between formats",
    input_schema: %{
      type: :object,
      properties: %{
        data: %{type: :object},
        format: %{type: :string, enum: ["json", "xml", "csv"]}
      }
    }

  def handler(%{data: data, format: format}, _ctx) do
    case format do
      "json" -> {:ok, Jason.encode!(data)}
      "xml" -> {:ok, XmlBuilder.document(data)}
      "csv" -> {:ok, CSV.encode(data)}
    end
  end
end
```

### Integration Prisms
Connect to external services:

```elixir
defmodule MyApp.Prisms.EmailSender do
  use Lux.Prism,
    name: "Email Sender",
    description: "Sends emails via SMTP",
    input_schema: %{
      type: :object,
      properties: %{
        to: %{type: :string},
        subject: %{type: :string},
        body: %{type: :string}
      },
      required: ["to", "subject", "body"]
    }

  def handler(params, _ctx) do
    case Swoosh.Mailer.deliver(build_email(params)) do
      {:ok, _} -> {:ok, %{sent: true}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_email(%{to: to, subject: subject, body: body}) do
    Swoosh.Email.new()
    |> Swoosh.Email.to(to)
    |> Swoosh.Email.subject(subject)
    |> Swoosh.Email.text_body(body)
  end
end
```

### Business Logic Prisms
Implement business rules and workflows:

```elixir
defmodule MyApp.Prisms.OrderProcessor do
  use Lux.Prism,
    name: "Order Processor",
    description: "Processes orders with business rules",
    input_schema: %{
      type: :object,
      properties: %{
        order: %{
          type: :object,
          properties: %{
            items: %{type: :array},
            total: %{type: :number},
            customer: %{type: :object}
          }
        }
      }
    }

  def handler(%{order: order}, ctx) do
    with :ok <- validate_inventory(order.items),
         :ok <- validate_payment(order.total),
         {:ok, processed} <- apply_discounts(order) do
      {:ok, %{
        order_id: generate_order_id(),
        processed_at: DateTime.utc_now(),
        final_total: processed.total
      }}
    end
  end
end
```

## Best Practices

1. **Input/Output Schemas**
   - Define clear, specific schemas
   - Document all properties
   - Use appropriate types and constraints
   - Include examples where helpful

2. **Error Handling**
   - Return `{:ok, result}` or `{:error, reason}`
   - Provide meaningful error messages
   - Handle all error cases
   - Use pattern matching for validation

3. **Context Usage**
   - Use context for cross-cutting concerns
   - Don't rely on global state
   - Pass necessary data through context
   - Keep context usage minimal

4. **Testing**
   - Test happy and error paths
   - Mock external dependencies
   - Test with various inputs
   - Test error conditions

Example test:
```elixir
defmodule MyApp.Prisms.TextAnalysisTest do
  use ExUnit.Case, async: true

  alias MyApp.Prisms.TextAnalysis

  describe "run/2" do
    test "analyzes positive text" do
      {:ok, result} = TextAnalysis.run(%{
        text: "Great product!",
        language: "en"
      })

      assert result.sentiment == "positive"
      assert result.confidence > 0.8
      assert "great" in result.key_phrases
    end

    test "handles empty text" do
      assert {:error, _} = TextAnalysis.run(%{
        text: "",
        language: "en"
      })
    end
  end
end
```

## Advanced Topics

### Composable Prisms

Prisms can be composed together:

```elixir
defmodule MyApp.Prisms.Pipeline do
  use Lux.Prism,
    name: "Processing Pipeline",
    description: "Chains multiple prisms"

  def handler(input, ctx) do
    with {:ok, validated} <- MyApp.Prisms.Validator.run(input),
         {:ok, enriched} <- MyApp.Prisms.Enricher.run(validated),
         {:ok, processed} <- MyApp.Prisms.Processor.run(enriched) do
      {:ok, processed}
    end
  end
end
```

### Async Prisms

Handle long-running operations:

```elixir
defmodule MyApp.Prisms.AsyncProcessor do
  use Lux.Prism,
    name: "Async Processor",
    description: "Handles async operations"

  def handler(input, ctx) do
    task = Task.async(fn ->
      # Long running operation
      Process.sleep(5000)
      {:ok, %{result: "done"}}
    end)

    case Task.yield(task, :timer.seconds(10)) do
      {:ok, result} -> result
      nil ->
        Task.shutdown(task)
        {:error, :timeout}
    end
  end
end 
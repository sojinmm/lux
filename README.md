# Lux

Lux is an Elixir framework for building modular, adaptive, and collaborative multi-agent systems. It enables autonomous entities (Specters) to communicate, plan, and execute workflows in dynamic environments.

## Core Concepts

Lux is built around four core abstractions that work together to create powerful agent-based systems:

### Signals
Signals are the fundamental units of communication in Lux. They represent structured data that flows between components and agents. Each Signal:
- Has a defined schema that validates its structure
- Carries metadata about its origin and purpose
- Can be transformed and validated
- Enables type-safe communication

Example of a Signal definition:
```elixir
defmodule MyApp.Signals.ChatMessage do
  use Lux.Signal,
    schema: MyApp.Schemas.ChatMessageSchema

  def validate(%{content: content} = message) when byte_size(content) > 0 do
    {:ok, message}
  end
  def validate(_), do: {:error, "Message content cannot be empty"}

  def transform(message) do
    {:ok, Map.put(message, :timestamp, DateTime.utc_now())}
  end
end

defmodule MyApp.Schemas.ChatMessageSchema do
  use Lux.SignalSchema,
    name: "chat_message",
    version: "1.0.0",
    description: "Represents a chat message in the system",
    schema: %{
      type: :object,
      properties: %{
        content: %{type: :string},
        from: %{type: :string},
        to: %{type: :string},
        timestamp: %{type: :string, format: "date-time"}
      },
      required: ["content", "from", "to"]
    }
end
```

### Prisms
Prisms are modular units of functionality that can be composed into workflows. They:
- Have well-defined inputs and outputs
- Can be tested in isolation
- Support validation and transformation
- Can be reused across different workflows

Example of a Prism:
```elixir
defmodule MyApp.Prisms.SentimentAnalysis do
  use Lux.Prism,
    name: "Sentiment Analysis",
    description: "Analyzes text sentiment using NLP",
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
        sentiment: %{type: :string, enum: ["positive", "negative", "neutral"]},
        confidence: %{type: :number, minimum: 0, maximum: 1}
      },
      required: ["sentiment", "confidence"]
    }

  def handler(%{text: text, language: lang}, _ctx) do
    # Implementation
    {:ok, %{sentiment: "positive", confidence: 0.95}}
  end
end
```

### Lenses
Lenses provide a way to interact with external systems and APIs. They:
- Handle authentication and authorization
- Transform data between systems
- Manage rate limiting and retries
- Support different protocols and formats

Example of a Lens:
```elixir
defmodule MyApp.Lenses.WeatherAPI do
  use Lux.Lens,
    name: "OpenWeather API",
    description: "Fetches weather data from OpenWeather",
    url: "https://api.openweathermap.org/data/2.5/weather",
    method: :get,
    auth: %{type: :api_key, key: System.get_env("OPENWEATHER_API_KEY")},
    schema: %{
      type: :object,
      properties: %{
        city: %{type: :string},
        units: %{type: :string, enum: ["metric", "imperial"]}
      },
      required: ["city"]
    }

  def after_focus(%{"main" => %{"temp" => temp}} = response) do
    {:ok, %{temperature: temp, raw_data: response}}
  end
end
```

### Beams
Beams orchestrate workflows by combining multiple steps into sequential, parallel, or conditional execution paths. They support:

- Sequential execution
- Parallel processing with automatic context merging
- Conditional branching with dynamic evaluation
- Parameter references between steps
- Execution logging and error handling

Example of a complex beam:
```elixir
defmodule MyApp.Beams.TradingWorkflow do
  use Lux.Beam,
    name: "Trading Workflow",
    description: "Analyzes and executes trades",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        amount: %{type: :number}
      },
      required: ["symbol", "amount"]
    },
    generate_execution_log: true

  @impl true
  def steps do
    sequence do
      step(:market_data, MyApp.Prisms.MarketData, %{symbol: :symbol})

      parallel do
        step(:technical, MyApp.Prisms.TechnicalAnalysis,
          %{data: {:ref, "market_data"}},
          retries: 3,
          store_io: true)

        step(:sentiment, MyApp.Prisms.SentimentAnalysis,
          %{symbol: :symbol},
          timeout: :timer.seconds(30))
      end

      branch {__MODULE__, :should_trade?} do
        true -> step(:execute, MyApp.Prisms.ExecuteTrade, %{
          symbol: :symbol,
          amount: :amount,
          signals: {:ref, "technical"}
        })
        false -> step(:skip, MyApp.Prisms.LogDecision, %{
          reason: "Unfavorable conditions"
        })
      end
    end
  end

  def should_trade?(ctx) do
    ctx.technical.score > 0.7 && ctx.sentiment.confidence > 0.8
  end
end
```

## Advanced Topics

### Schema Validation and Evolution
Lux provides robust schema validation and evolution through SignalSchemas:
- Version management
- Compatibility checking
- Schema documentation
- Runtime validation

### Error Handling and Recovery
The framework includes comprehensive error handling:
- Automatic retries with backoff
- Error logging and tracking
- Recovery strategies

### Testing and Development
Lux is designed for testability:
- Isolated component testing
- Workflow simulation
- Mock external services
- Performance testing

### Monitoring and Observability
Built-in monitoring capabilities:
- Execution logging
- Performance metrics
- Error tracking
- Workflow visualization

## Installation

The package can be installed by adding `lux` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lux, "~> 0.1.0"}
  ]
end
```

## Development Setup

### Elixir Setup

```bash
# Install dependencies
mix deps.get

# Run Elixir tests
mix test
```

### Python Setup

The project includes Python components in the `priv/python` directory. These are managed using Poetry.

1. Install Poetry (if not already installed):
   ```bash
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. Install Python dependencies:
   ```bash
   cd priv/python
   poetry install
   ```

## Running Tests

### Elixir Tests
```bash
# Run all Elixir tests
mix test

# Run specific test file
mix test test/lux/python_test.exs
```

### Python Tests
```bash
# Run all Python tests
mix python.test

# Run specific test file
mix python.test tests/test_eval.py

# Run tests with coverage
mix python.test --cov

# Run tests with specific marker
mix python.test --marker="not slow"
```

You can also run Python tests directly using Poetry:
```bash
cd priv/python
poetry run pytest
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```bash
mix docs
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

Lux is released under the MIT License.

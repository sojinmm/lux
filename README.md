# Lux

[![Build Status](https://github.com/spectrallabs/lux/workflows/CI/badge.svg)](https://github.com/spectrallabs/lux/actions)
[![Hex.pm](https://img.shields.io/hexpm/v/lux.svg)](https://hex.pm/packages/lux)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lux)

Lux is a powerful Elixir framework for building modular, adaptive, and collaborative multi-agent systems. It enables autonomous entities (Specters) to communicate, plan, and execute workflows in dynamic environments.

## Why Lux?

- 🚀 **Modular Architecture**: Build complex systems from simple, reusable components
- 🔄 **Type-Safe Communication**: Structured data flow with schema validation
- 🤖 **AI-Ready**: First-class support for LLM-based workflows
- 🔌 **Extensible**: Easy integration with external services and APIs
- 📊 **Observable**: Built-in monitoring and debugging tools
- 🧪 **Testable**: Comprehensive testing utilities for all components

## Quick Start

```elixir
# Add Lux to your dependencies
def deps do
  [
    {:lux, "~> 0.1.0"}
  ]
end

# Create your first Prism
defmodule MyApp.Prisms.Greeter do
  use Lux.Prism,
    name: "Greeter",
    description: "Generates personalized greetings",
    input_schema: %{
      type: :object,
      properties: %{
        name: %{type: :string}
      },
      required: ["name"]
    }

  def handler(%{name: name}, _ctx) do
    {:ok, %{greeting: "Hello, #{name}!"}}
  end
end

# Use it in your application
{:ok, result} = MyApp.Prisms.Greeter.run(%{name: "World"})
IO.puts(result.greeting) # Outputs: Hello, World!
```

## Core Concepts

Lux is built around four powerful abstractions:

### 1. Signals 📡
Type-safe communication units with schema validation and transformation capabilities.
[Learn more about Signals](guides/signals.md)

### 2. Prisms 🔮
Modular units of functionality that can be composed into workflows.
[Learn more about Prisms](guides/prisms.md)

### 3. Lenses 🔍
Interfaces to external systems and APIs with built-in error handling.
[Learn more about Lenses](guides/lenses.md)

### 4. Beams 🌟
Workflow orchestrators that combine components into powerful pipelines.
[Learn more about Beams](guides/beams.md)

[Previous core concepts content...]

## Real-World Use Cases

### AI Agent Workflows
```elixir
defmodule MyApp.Beams.AIAssistant do
  use Lux.Beam,
    name: "AI Assistant",
    description: "Processes user queries with AI"

  def steps do
    sequence do
      step(:understand, MyApp.Prisms.IntentRecognition)
      step(:research, MyApp.Prisms.WebSearch)
      step(:generate, MyApp.Prisms.ContentGeneration)
      step(:review, MyApp.Prisms.QualityCheck)
    end
  end
end
```

### Data Processing Pipeline
```elixir
defmodule MyApp.Beams.DataProcessor do
  use Lux.Beam,
    name: "Data Processor",
    description: "ETL pipeline with validation"

  def steps do
    sequence do
      parallel do
        step(:fetch_users, MyApp.Lenses.UserAPI)
        step(:fetch_orders, MyApp.Lenses.OrderAPI)
      end
      step(:transform, MyApp.Prisms.DataTransform)
      step(:validate, MyApp.Prisms.SchemaValidator)
      step(:load, MyApp.Lenses.DatabaseLoader)
    end
  end
end
```

## Development Setup

### Prerequisites
- Elixir 1.14 or later
- Python 3.11 or later
- Poetry for Python dependency management

## Contributing

We welcome contributions! Here's how you can help:

1. 🐛 Report bugs and suggest features in [Issues](https://github.com/spectrallabs/lux/issues)
2. 📖 Improve documentation
3. 🧪 Add tests and examples
4. 🔧 Submit pull requests

See our [Contributing Guide](CONTRIBUTING.md) for details.

## Community

- 💬 [Discord Community](https://discord.gg/luxframework)
- 📝 [Blog](https://blog.spectrallabs.xyz)
- 🐦 [Twitter](https://twitter.com/luxframework)

## License

Lux is released under the MIT License. See [LICENSE](LICENSE) for details.

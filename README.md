# Lux Framework

Lux is an open-source Elixir framework for building modular, adaptive, and collaborative multi-agent systems. Designed for developers and researchers alike, Lux enables autonomous entities (Specters) to communicate, plan, and execute workflows in dynamic environments. It integrates seamlessly with other languages and frameworks, offering flexibility and extensibility.

---

## Key Features

- **Specters:** Stateful autonomous agents that can evolve, communicate, and execute tasks.
- **Prisms:** Modular, composable units of functionality for defining actions.
- **Beams:** Flexible workflows that orchestrate multiple actions.
- **Lenses:** Event-driven sensors for data gathering and broadcasting.
- **Signals:** A robust messaging system enabling agent collaboration.
- **Reflections:** Dynamic Specter evolution, allowing agents to create new versions of themselves or generate workflows on the fly.
- **Multi-Language Support:** Integrates Python, TypeScript, and other languages via Venomous.
- **Observability:** Built-in telemetry and debugging tools for seamless monitoring.

---

## Installation

Add `lux` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lux, "~> 0.1.0"}
  ]
end
```

Run `mix deps.get` to fetch the dependency.

---

## Getting Started

### Defining a Prism
A Prism represents a discrete action. For example, here’s a Prism that adds two numbers:

```elixir
defmodule MyApp.Prism.Add do
  use Lux.Prism,
    name: "add",
    description: "Adds two numbers",
    schema: [
      value: [type: :number, required: true],
      amount: [type: :number, required: true]
    ]

  @impl true
  def run(%{value: value, amount: amount}, _context) do
    {:ok, %{result: value + amount}}
  end
end
```

### Calling Python Code in a Prism
Prisms can integrate external logic using Venomous to run Python code:

```elixir
defmodule MyApp.Prism.PythonAdd do
  use Lux.Prism,
    name: "python_add",
    description: "Adds two numbers using Python",
    schema: [
      value: [type: :number, required: true],
      amount: [type: :number, required: true]
    ]

  @impl true
  def run(%{value: value, amount: amount}, _context) do
    script = """
    def add(a, b):
        return a + b

    result = add({value}, {amount})
    """

    Lux.Venomous.run(:python, script, %{value: value, amount: amount})
  end
end
```

### Creating a Specter
A Specter combines workflows and communicates with other agents:

```elixir
defmodule MyApp.Specter.CEO do
  use Lux.Specter,
    name: "CEO Agent",
    description: "Manages hedge fund strategy and coordinates agents"

  @impl true
  def plan(%__MODULE__{} = specter) do
    {:ok, [
      {MyApp.Beams.GatherInsights, %{}},
      {MyApp.Beams.ExecuteTrades, %{}}
    ]}
  end

  @impl true
  def reflect(%__MODULE__{} = specter, new_capability) do
    {:ok, Lux.Reflections.create_new_version(specter, new_capability)}
  end
end
```

### Defining a Beam
Beams orchestrate workflows by combining multiple Prisms:

```elixir
defmodule MyApp.Beams.GatherInsights do
  use Lux.Beam,
    name: "Gather Insights",
    description: "Aggregates trading signals and risk assessments"

  @impl true
  def steps do
    [
      {MyApp.Prism.AlphaSignals, %{symbol: "BTC", interval: "1h"}},
      {MyApp.Prism.RiskAssessment, %{positions: [%{symbol: "BTC", value: 10000, volatility: 0.05}], max_risk: 0.15}}
    ]
  end
end
```

### Defining a Lens
Lenses are event-driven sensors for gathering and broadcasting data:

```elixir
defmodule MyApp.Lens.MarketData do
  use Lux.Lens,
    name: "Market Data Lens",
    description: "Monitors market prices and broadcasts updates",
    schema: [
      symbol: [type: :string, required: true],
      price: [type: :float, required: true]
    ]

  @impl true
  def observe(%{symbol: symbol, price: price}) do
    IO.puts("Market update: #{symbol} is now $#{price}")
    {:ok, %{symbol: symbol, price: price}}
  end
end
```

### Defining a Signal
Signals facilitate communication between Specters:

```elixir
defmodule MyApp.Signal.Message do
  use Lux.Signal,
    name: "Message Signal",
    description: "Facilitates inter-agent communication",
    schema: [
      sender: [type: :string, required: true],
      room_id: [type: :string, required: true],
      content: [type: :map, required: true]
    ]

  @impl true
  def broadcast(%{sender: sender, room_id: room_id, content: content}) do
    IO.puts("#{sender} in room #{room_id}: #{inspect(content)}")
    {:ok, content}
  end
end
```

### YAML Workflow Example
Lux supports defining workflows in YAML for non-Elixir developers. Here’s an example:

```yaml
specter:
  name: CEO Agent
  description: Manages the hedge fund
  beams:
    - name: GatherInsights
      steps:
        - action: AlphaSignals
          params:
            symbol: BTC
            interval: 1h
        - action: RiskAssessment
          params:
            positions:
              - symbol: BTC
                value: 10000
                volatility: 0.05
            max_risk: 0.15
```

### Advanced Example: Inter-Agent Collaboration
This example shows agents collaborating via Signals and Lenses.

#### Risk Agent
```elixir
defmodule MyApp.Specter.RiskAgent do
  use Lux.Specter,
    name: "Risk Agent",
    description: "Evaluates trading risks and provides feedback"

  @impl true
  def plan(%__MODULE__{} = specter) do
    {:ok, [
      {MyApp.Prism.RiskAssessment, %{positions: [%{symbol: "BTC", value: 10000, volatility: 0.05}], max_risk: 0.15}}
    ]}
  end
end
```

#### Alpha Signals Agent
```elixir
defmodule MyApp.Specter.AlphaSignalsAgent do
  use Lux.Specter,
    name: "Alpha Signals Agent",
    description: "Generates trading signals based on market data"

  @impl true
  def plan(%__MODULE__{} = specter) do
    {:ok, [
      {MyApp.Prism.AlphaSignals, %{symbol: "BTC", interval: "1h"}}
    ]}
  end
end
```

#### CEO Agent Utilizing Collaboration
```elixir
defmodule MyApp.Specter.CEO do
  use Lux.Specter,
    name: "CEO Agent",
    description: "Manages hedge fund strategy and coordinates agents"

  @impl true
  def plan(%__MODULE__{} = specter) do
    {:ok, [
      {MyApp.Beams.GatherInsights, %{}},
      {MyApp.Beams.ExecuteTrades, %{}}
    ]}
  end

  @impl true
  def handle_signal(%Lux.Signal.Message{content: %{risk: risk, alpha: alpha}}) do
    if risk <= 0.15 and alpha > 0.8 do
      IO.puts("Trade approved with alpha #{alpha} and risk #{risk}")
      {:ok, :trade}
    else
      IO.puts("Trade rejected due to risk #{risk} or low alpha #{alpha}")
      {:error, :reject}
    end
  end
end
```

---

## Advanced Features

- **Dynamic Reflections:** Specters can generate new versions or workflows on the fly.
- **Telemetry and Debugging:** Built-in tools for monitoring and debugging workflows.
- **Inter-Agent Communication:** Specters use Signals and Lenses to collaborate in real-time.

---

## Example Use Case: Crypto Hedge Fund
### Agents:
1. **CEO Agent:** Coordinates tasks and makes trading decisions.
2. **Alpha Signals Agent:** Analyzes market data to generate signals.
3. **Risk Agent:** Evaluates risk and ensures compliance with constraints.
4. **Marketing Agent:** Posts updates to social media based on fund activity.

### Workflow:
1. Gather trading signals from the Alpha Signals Agent.
2. Evaluate risk with the Risk Agent.
3. Execute trades and publish updates via the Marketing Agent.

---

## Community and Contribution
We welcome contributions to Lux! Feel free to submit issues, fork the repository, and create pull requests. Join the discussion to help improve Lux and build the next generation of multi-agent systems.

---

## License
Lux is open-source software licensed under the MIT License.

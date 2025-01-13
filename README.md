# Lux

Lux is an Elixir framework for building modular, adaptive, and collaborative multi-agent systems. It enables autonomous entities (Specters) to communicate, plan, and execute workflows in dynamic environments.

## Core Concepts

### Beams
Beams orchestrate workflows by combining multiple steps into sequential, parallel, or conditional execution paths. They support:

- Sequential execution
- Parallel processing with automatic context merging
- Conditional branching with dynamic evaluation
- Parameter references between steps
- Execution logging and error handling

Example of a basic beam:

```elixir
defmodule MyApp.Beams.TradingWorkflow do
  use Lux.Beam,
    name: "Trading Workflow",
    description: "Analyzes market data",
    input_schema: [symbol: [type: :string]]

  @impl true
  def steps do
    sequence do
      step(:market_data, MarketDataPrism, %{symbol: :symbol})

      parallel do
        step(:technical, TechnicalAnalysisPrism,
          %{data: {:ref, "market_data"}},
          retries: 3)
        step(:sentiment, SentimentAnalysisPrism,
          %{symbol: :symbol},
          store_io: true)
      end

      branch {__MODULE__, :should_trade?} do
        true -> step(:execute, TradePrism, %{
          symbol: :symbol,
          signals: {:ref, "technical"}
        })
        false -> step(:skip, LogPrism, %{
          reason: "Unfavorable conditions"
        })
      end
    end
  end

  def should_trade?(ctx) do
    get_in(ctx, ["technical", :score]) > 0.7 && 
    get_in(ctx, ["sentiment", :confidence]) > 0.8
  end
end
```

### Features

- **Step Configuration**
  - Timeouts (default: 5 minutes)
  - Retries with configurable backoff
  - Dependency management
  - Execution logging
  - Input/Output validation

- **Parameter References**
  - Reference previous step outputs using `{:ref, "step_id"}`
  - Nested references with dot notation
  - Automatic context management

### Complex Example: Agent Management

Here's an example of a beam that manages other agents:

```elixir
defmodule MyApp.Beams.HiringManager do
  use Lux.Beam, generate_execution_log: true
    
  def steps do
    sequence do
      step(:workforce_metrics, WorkforceAnalysisPrism, %{
        team_size: {:ref, "current_team_size"},
        performance_data: {:ref, "agent_performance_metrics"}
      })
      
      branch {__MODULE__, :needs_scaling?} do
        :scale_up ->
          sequence do
            step(:candidate_search, AgentSearchPrism, %{
              required_skills: {:ref, "workforce_metrics.skill_gaps"}
            })
            
            step(:candidate_evaluation, AgentEvaluationPrism, %{
              candidates: {:ref, "candidate_search.results"}
            })
          end
          
        :scale_down ->
          step(:termination, AgentTerminationPrism, %{
            agents: {:ref, "workforce_metrics.underperforming_agents"},
            reassign_tasks: true
          })
      end
    end
  end
end
```

### Installation

```elixir
def deps do
  [
    {:lux, "~> 0.1.0"}
  ]
end
```

## Documentation

For detailed documentation and examples, see:
- [Beam Documentation](lib/lux/beam.ex)
- [Runner Implementation](lib/lux/beam/runner.ex)
- [Test Examples](test/lux/beam_test.exs)

## License

Lux is released under the MIT License.

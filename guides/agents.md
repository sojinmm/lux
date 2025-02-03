# Agents Guide

Agents are autonomous components in Lux that can interact with LLMs, process signals, and execute workflows. They combine intelligence with execution capabilities, making them perfect for building conversational and agentic applications.

## Overview

An Agent consists of:
- A unique identifier
- Name and description
- Goal or purpose
- LLM configuration
- Memory configuration (optional)
- Optional components (Prisms, Beams, Lenses)
- Signal handling capabilities

## Creating an Agent

Here's a basic example of an Agent:

```elixir
defmodule MyApp.Agents.Assistant do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Simple Assistant",
      description: "A helpful assistant that can engage in conversations",
      goal: "Help users by providing clear and accurate responses",
      llm_config: %{
        api_key: Application.get_env(:lux, :api_keys)[:openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.7
      }
    })
  end
end
```

## Agent Configuration

### Memory Configuration
Agents can be configured with memory to maintain state and recall previous interactions:

```elixir
defmodule MyApp.Agents.MemoryAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Memory-Enabled Assistant",
      description: "An assistant that remembers past interactions",
      goal: "Help users while maintaining context of conversations",
      memory_config: %{
        backend: Lux.Memory.SimpleMemory,
        name: :memory_agent_store
      },
      llm_config: %{
        api_key: Application.get_env(:lux, :api_keys)[:openai],
        model: Application.get_env(:lux, :open_ai_models)[:smartest],
        temperature: 0.7
      }
    })
  end

  @impl true
  def chat(agent, message, opts) do
    # Store the user's message
    {:ok, _} = Lux.Memory.SimpleMemory.add(
      agent.memory_pid,
      message,
      :interaction,
      %{role: :user}
    )

    case super(agent, message, opts) do
      {:ok, response} = ok ->
        # Store the assistant's response
        {:ok, _} = Lux.Memory.SimpleMemory.add(
          agent.memory_pid,
          response,
          :interaction,
          %{role: :assistant}
        )
        ok
      error -> error
    end
  end
end
```

### LLM Configuration
Control how your agent interacts with language models:

```elixir
llm_config: %{
  api_key: Application.get_env(:lux, :api_keys)[:openai],
  model: "gpt-4",
  temperature: 0.7,
  max_tokens: 1000
}
```

### Structured Responses
Define schemas to get structured responses from your agent:

```elixir
defmodule MyApp.Schemas.ResponseSchema do
  use Lux.SignalSchema,
    schema: %{
      type: :object,
      properties: %{
        message: %{type: :string, description: "The content of the response"}
      },
      required: [:message]
    }
end

defmodule MyApp.Agents.StructuredAssistant do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Structured Assistant",
      description: "An assistant that provides structured responses",
      llm_config: %{
        # ... basic config ...
        json_schema: ResponseSchema  # Define response structure
      }
    })
  end
end
```

## Agent Types

### Chat Agent
A simple conversational agent:

```elixir
defmodule MyApp.Agents.ChatAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: opts[:name] || "Chat Assistant",
      description: "A conversational assistant",
      goal: "Engage in helpful dialogue",
      llm_config: %{
        api_key: Application.get_env(:lux, :api_keys)[:openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.7,
        messages: [
          %{
            role: "system",
            content: """
            You are a helpful chat assistant.
            Respond to users in a clear and concise manner.
            """
          }
        ]
      }
    })
  end
end
```

### Personality-Driven Agent
An agent with a distinct personality:

```elixir
defmodule MyApp.Agents.FunAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Fun Assistant",
      description: "A playful and witty AI assistant who loves jokes",
      goal: "Make conversations fun and engaging while being helpful",
      llm_config: %{
        api_key: Application.get_env(:lux, :api_keys)[:openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.8,  # Higher temperature for more creative responses
        messages: [
          %{
            role: "system",
            content: """
            You are a fun and witty assistant. You love making jokes and puns.
            Keep your responses light-hearted but still helpful.
            When explaining technical concepts, use fun analogies and examples.
            """
          }
        ]
      }
    })
  end
end
```

## Using Agents

### Starting an Agent
Agents can be used as GenServers, so you can start them like this:

```elixir
{:ok, pid} = MyApp.Agents.ChatAgent.start_link()
```

### Sending Messages
Chat with your agent:

```elixir
# Basic chat
{:ok, response} = ChatAgent.send_message(pid, "Hello!")

# With structured responses
{:ok, %Lux.Signal{payload: %{message: content}}} = 
  StructuredAgent.send_message(pid, "Tell me a joke!")
```

### Working with Memory
Access an agent's memory:

```elixir
# Get recent interactions
{:ok, recent} = Lux.Memory.SimpleMemory.recent(agent.memory_pid, 5)

# Search for specific content
{:ok, matches} = Lux.Memory.SimpleMemory.search(agent.memory_pid, "specific topic")

# Get interactions within a time window
start_time = DateTime.utc_now() |> DateTime.add(-3600) # 1 hour ago
end_time = DateTime.utc_now()
{:ok, window} = Lux.Memory.SimpleMemory.window(agent.memory_pid, start_time, end_time)
```

## Best Practices

1. **Agent Design**
   - Give agents clear, focused purposes
   - Use descriptive names and goals
   - Keep system messages concise but informative

2. **Response Structure**
   - Use schemas for predictable responses
   - Consider the tradeoff between flexibility and structure
   - Document expected response formats

3. **Configuration**
   - Use application config for API keys
   - Choose appropriate temperature settings
   - Set reasonable token limits

4. **Error Handling**
   - Handle API errors gracefully
   - Provide meaningful error messages
   - Consider retry strategies for transient failures

5. **Testing**
   - Test agent behavior with different inputs
   - Mock LLM responses in tests
   - Verify structured response handling

```elixir
defmodule MyApp.Agents.ChatAgentTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = MyApp.Agents.ChatAgent.start_link()
    {:ok, agent: pid}
  end

  test "can chat with the agent", %{agent: pid} do
    {:ok, response} = ChatAgent.send_message(pid, "Hello!")
    assert is_binary(response)
    assert String.length(response) > 0
  end

  test "handles errors gracefully", %{agent: pid} do
    # Simulate API error
    agent = %{agent | llm_config: %{api_key: "invalid"}}
    assert {:error, :invalid_api_key} = 
      ChatAgent.send_message(pid, "This should fail")
  end
end
```

## Advanced Features

### Signal Handling
Agents can process signals from other components:

```elixir
defmodule MyApp.Agents.SignalAwareAgent do
  use Lux.Agent

  @impl true
  def handle_signal(agent, %{schema_id: MyApp.Schemas.TaskSignal} = signal) do
    # Process the task signal
    {:ok, process_task(signal.payload)}
  end

  def handle_signal(_agent, _signal), do: :ignore
end
```

### Component Integration
Combine agents with other Lux components:

```elixir
defmodule MyApp.Agents.SmartAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Smart Assistant",
      prisms: [MyApp.Prisms.DataAnalysis],
      beams: [MyApp.Beams.TaskProcessor],
      lenses: [MyApp.Lenses.DataViewer],
      # ... rest of config ...
    })
  end
end
``` 
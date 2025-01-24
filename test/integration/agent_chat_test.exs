defmodule Lux.Integration.AgentChatTest do
  use IntegrationCase, async: true

  alias Lux.LLM.OpenAI.Config, as: LLMConfig

  # Fixed seed for deterministic responses in tests
  @seed 42

  defmodule TestPrism do
    @moduledoc """
    A test prism that can be used to test the agent.
    """
    use Lux.Prism,
      name: "#{TestPrism}",
      id: TestPrism,
      description: "A test prism that can be used to test the agent.",
      input_schema: %{
        type: "object",
        properties: %{message: %{type: "string"}},
        required: [:message]
      }

    def handler(%{"message" => message}, _opts) do
      {:ok, %{message: message <> " from TestPrism"}}
    end
  end

  defmodule ChatAgent do
    @moduledoc """
    An example agent that can engage in chat conversations.
    """
    use Lux.Agent

    @impl true
    def new(opts) do
      Lux.Agent.new(%{
        name: opts[:name] || "Chat Assistant",
        description:
          opts[:description] || "A helpful chat assistant that can engage in conversations",
        goal:
          opts[:goal] ||
            "Help users by engaging in meaningful conversations and providing assistance. You keep your responses short and concise.",
        module: __MODULE__,
        prisms: [
          TestPrism
        ],
        llm_config: %{
          api_key: opts[:api_key] || Application.get_env(:lux, :api_keys)[:integration_openai],
          model: opts[:model] || Application.get_env(:lux, :open_ai_models)[:cheapest],
          temperature: opts[:temperature] || 0.7,
          max_tokens: opts[:max_tokens] || 1000,
          receive_timeout: opts[:receive_timeout] || 30_000,
          messages: [
            %{
              role: "system",
              content: """
              You are #{opts[:name] || "Chat Assistant"}. #{opts[:description] || "A helpful chat assistant that can engage in conversations"}
              Your goal is: #{opts[:goal] || "Help users by engaging in meaningful conversations and providing assistance"}
              Respond to the user's message in a helpful and engaging way.
              """
            }
          ]
        }
      })
    end
  end

  describe "agent chat" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.0,
        max_tokens: 50,
        seed: @seed
      }

      # Create and start a new chat agent
      {:ok, pid} =
        ChatAgent.start_link(%{
          name: "Research Assistant",
          description:
            "An AI research assistant specialized in scientific literature and analysis",
          goal: "Help researchers find, understand, and analyze scientific papers",
          llm_config: config
        })

      {:ok, pid: pid}
    end

    test "can chat with the agent", %{pid: pid} do
      {:ok, response} = ChatAgent.send_message(pid, "Can you define petricor?")

      assert is_binary(response)
      assert String.length(response) > 0
      # The response should be relevant to petrology
      assert response =~ ~r/minerals|smell|rain/i
    end

    test "respects LLM configuration options" do
      # Create an agent with specific LLM settings
      {:ok, pid} =
        ChatAgent.start_link(%{
          name: "Research Assistant",
          llm_config: %LLMConfig{
            api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
            model: Application.get_env(:lux, :open_ai_models)[:cheapest],
            temperature: 0.1,
            max_tokens: 50,
            seed: @seed
          }
        })

      {:ok, response} = ChatAgent.send_message(pid, "Give a very brief hello")
      assert is_binary(response)
      # Response should be concise due to max_tokens
      assert String.length(response) < 200
    end

    test "maintains consistent persona across chats", %{pid: pid} do
      # First chat to establish role
      {:ok, response1} = ChatAgent.send_message(pid, "What kind of assistant are you?")
      assert is_binary(response1)
      assert response1 =~ ~r/research|scientific|papers|literature/i

      # Second chat to verify consistent persona
      {:ok, response2} = ChatAgent.send_message(pid, "Can you help with academic papers?")
      assert is_binary(response2)
      assert response2 =~ ~r/research|papers|analysis|literature|scientific/i
    end

    test "can use prisms", %{pid: pid} do
      {:ok, %Lux.Signal{payload: %{content: nil, tool_calls_results: [%{message: message}]}}} =
        ChatAgent.send_message(pid, "Could you use the TestPrism for testing the agent?")

      assert is_binary(message)
      assert message =~ "from TestPrism"
    end
  end
end

defmodule Lux.Integration.AgentChatTest do
  use IntegrationCase, async: true

  alias Lux.Agent.NewRunner
  alias Lux.Examples.ChatAgent
  alias Lux.LLM.OpenAI.Config, as: LLMConfig

  # 30 seconds timeout for GenServer calls
  @timeout 30_000
  # Fixed seed for deterministic responses in tests
  @seed 42

  describe "agent chat" do
    setup do
      config = %LLMConfig{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.0,
        max_tokens: 50,
        seed: @seed
      }

      # Create a new chat agent with longer timeout
      agent =
        ChatAgent.new(%{
          name: "Research Assistant",
          description:
            "An AI research assistant specialized in scientific literature and analysis",
          goal: "Help researchers find, understand, and analyze scientific papers",
          llm_config: config
        })

      # Start the agent process with the new runner
      {:ok, pid} = NewRunner.start_link(agent)

      {:ok, agent: agent, pid: pid}
    end

    test "can chat with the agent", %{pid: pid} do
      {:ok, response} =
        NewRunner.chat(pid, "Can you define petricor?", [], @timeout)

      assert is_binary(response)
      assert String.length(response) > 0
      # The response should be relevant to petrology
      assert response =~ ~r/minerals|smell|rain/i
    end

    test "handles chat errors gracefully", %{agent: agent} do
      # Create an agent with invalid API key
      agent = put_in(agent.llm_config.api_key, "invalid_key")
      {:ok, pid} = NewRunner.start_link(agent)

      assert {:error, :invalid_api_key} = NewRunner.chat(pid, "This should fail", [], @timeout)
    end

    test "respects LLM configuration options", %{agent: agent} do
      # Create an agent with specific LLM settings
      agent = %{
        agent
        | llm_config: %LLMConfig{
            agent.llm_config
            | temperature: 0.1,
              # Very short response
              max_tokens: 50,
              # Keep the same seed
              seed: @seed
          }
      }

      {:ok, pid} = NewRunner.start_link(agent)

      {:ok, response} = NewRunner.chat(pid, "Give a very brief hello", [], @timeout)
      assert is_binary(response)
      # Response should be concise due to max_tokens
      assert String.length(response) < 200
    end

    test "maintains consistent persona across chats", %{pid: pid} do
      # First chat to establish role
      {:ok, response1} = NewRunner.chat(pid, "What kind of assistant are you?", [], @timeout)
      assert is_binary(response1)
      assert response1 =~ ~r/research|scientific|papers|literature/i

      # Second chat to verify consistent persona
      {:ok, response2} = NewRunner.chat(pid, "Can you help with academic papers?", [], @timeout)
      assert is_binary(response2)
      assert response2 =~ ~r/research|papers|analysis|literature|scientific/i
    end
  end
end

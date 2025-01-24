defmodule Lux.Examples.ChatAgent do
  @moduledoc """
  An example agent that can engage in chat conversations.
  """
  use Lux.Agent

  alias Lux.LLM.OpenAI
  alias Lux.LLM.OpenAI.Config, as: LLMConfig

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
      llm_config: %LLMConfig{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
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

  @impl true
  def chat(agent, message, _opts) do
    case OpenAI.call(message, [], agent.llm_config) do
      {:ok, %{payload: %{content: content}}} when is_map(content) ->
        # If content is a map, convert it to a string representation
        {:ok, format_content(content)}

      {:ok, %{payload: %{content: content}}} when is_binary(content) ->
        {:ok, content}

      {:error, reason} ->
        {:error, reason}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, error["message"] || "Unknown error"}

      unexpected ->
        {:error, {:unexpected_response, unexpected}}
    end
  end

  # Helper function to format map content into a readable string
  defp format_content(content) when is_map(content) do
    Enum.map_join(content, "\n", fn {k, v} -> "#{k}: #{format_value(v)}" end)
  end

  defp format_value(value) when is_list(value) do
    Enum.map_join(value, ", ", &format_value/1)
  end

  defp format_value(value) when is_map(value), do: format_content(value)
  defp format_value(value), do: to_string(value)
end

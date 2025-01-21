defmodule Lux.LLM.OpenAI do
  @moduledoc """
  OpenAI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.Response
  alias Lux.Prism

  require Beam
  require Lens
  require Prism
  require Response

  @endpoint "https://api.openai.com/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for OpenAI.
    """
    @type t :: %__MODULE__{
            api_key: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            frequency_penalty: float(),
            presence_penalty: float(),
            max_tokens: integer()
          }

    defstruct api_key: nil,
              model: "gpt-3.5-turbo",
              temperature: 0.7,
              top_p: 1.0,
              frequency_penalty: 0.0,
              presence_penalty: 0.0,
              max_tokens: 1000
  end

  @impl true
  def call(prompt, tools, options) do
    %Config{} = config = Keyword.fetch!(options, :config)

    messages = [
      %{role: "user", content: prompt}
    ]

    tools_config = Enum.map(tools, &tool_to_function/1)

    body = %{
      model: config.model,
      messages: messages,
      tools: tools_config,
      tool_choice: "auto",
      temperature: config.temperature,
      top_p: config.top_p,
      frequency_penalty: config.frequency_penalty,
      presence_penalty: config.presence_penalty,
      max_tokens: config.max_tokens
    }

    [
      url: @endpoint,
      headers: [
        {"Authorization", "Bearer #{config.api_key}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post(json: body)
    |> case do
      {:ok, %{status: 200} = response} -> handle_response(response)
      {:error, error} -> {:error, "OpenAI API error: #{inspect(error)}"}
    end
  end

  def tool_to_function(%Beam{name: name, description: description, input_schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_beam",
        description: description || "",
        parameters: %{
          type: "object",
          properties: schema_to_properties(schema)
        }
      }
    }
  end

  def tool_to_function(%Prism{name: name, description: description, input_schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name,
        description: description || "",
        parameters: %{
          type: "object",
          properties: schema_to_properties(schema)
        }
      }
    }
  end

  def tool_to_function(%Lens{name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}) do
    case body do
      %{"choices" => [%{"message" => message, "finish_reason" => finish_reason} | _]} ->
        {:ok, format_message(message, finish_reason)}

      %{"choices" => [%{"message" => message} | _]} ->
        {:ok, format_message(message, "stop")}

      _ ->
        {:error, "Unexpected response format"}
    end
  end

  defp format_message(%{"content" => content}, finish_reason) when not is_nil(content) do
    Response.response(content: content, finish_reason: finish_reason)
  end

  defp format_message(%{"tool_calls" => tool_calls}, finish_reason) do
    tool_calls =
      Enum.map(tool_calls, fn call ->
        %{
          type: call["type"],
          name: call["function"]["name"],
          params: Jason.decode!(call["function"]["arguments"])
        }
      end)

    Response.response(tool_calls: tool_calls, finish_reason: finish_reason)
  end

  defp schema_to_properties(nil), do: %{}
  defp schema_to_properties(%{} = schema) when map_size(schema) == 0, do: %{}

  defp schema_to_properties(%{type: "object", properties: properties}) do
    properties
  end

  defp schema_to_properties(schema) when is_list(schema) do
    Map.new(schema, fn {key, opts} ->
      {Atom.to_string(key),
       %{
         type: Atom.to_string(opts[:type] || :string),
         description: opts[:description] || ""
       }}
    end)
  end
end

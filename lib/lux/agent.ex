defmodule Lux.Agent do
  @moduledoc """
  A Agent defines an autonomous agent's capabilities, behaviors and goals.
  The actual execution and supervision is handled by the Lux runtime.
  """

  alias Lux.LLM

  @type scheduled_beam :: {module(), String.t(), keyword()}
  @type collaboration_protocol :: :ask | :tell | :delegate | :request_review

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          goal: String.t(),
          module: module(),
          prisms: [Lux.Prism.t()],
          beams: [Lux.Beam.t()],
          lenses: [Lux.Lens.t()],
          accepts_signals: [Lux.SignalSchema.t()],
          llm_config: map()
        }

  defstruct id: nil,
            name: "",
            description: "",
            goal: "",
            module: nil,
            prisms: [],
            beams: [],
            lenses: [],
            accepts_signals: [],
            llm_config: %{
              provider: :openai,
              model: "gpt-4",
              temperature: 0.7,
              max_tokens: 1000
            }

  @callback chat(t(), message :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback handle_signal(t(), Lux.Signal.t()) :: {:ok, term()} | :ignore | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.Agent
      @impl true
      def handle_signal(_agent, _signal) do
        :ignore
      end

      @impl true
      def chat(agent, message, _opts) do
        {:error, :not_implemented}
      end

      defoverridable chat: 3, handle_signal: 2
    end
  end

  @doc """
  Creates a new agent from the given attributes
  """
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, %{
      id: Map.get(attrs, :id, Lux.UUID.generate()),
      name: Map.get(attrs, :name, "Anonymous Agent"),
      description: Map.get(attrs, :description, ""),
      goal: Map.get(attrs, :goal, ""),
      module: Map.get(attrs, :module, __MODULE__),
      llm_config: Map.get(attrs, :llm_config, %{}),
      prisms: Map.get(attrs, :prisms, []),
      beams: Map.get(attrs, :beams, []),
      lenses: Map.get(attrs, :lenses, []),
      accepts_signals: Map.get(attrs, :accepts_signals, [])
    })
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  # Private helpers

  def handle_signal(agent, signal) do
    apply(agent, :handle_signal, [agent, signal])
  end

  @doc """
  Sends a chat message to the agent and returns its response.
  """
  def chat(%__MODULE__{module: module} = agent, message, opts \\ []) when is_atom(module) do
    apply(module, :chat, [agent, message, opts])
  end

  def chat(agent, message, _opts) do
    case LLM.call(message, [], agent.llm_config) do
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

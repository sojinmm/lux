defmodule Lux.Specter do
  @moduledoc """
  A Specter defines an autonomous agent's capabilities, behaviors and goals.
  The actual execution and supervision is handled by the Lux runtime.
  """

  require Record

  Record.defrecord(:specter, __MODULE__,
    id: nil,
    name: "",
    description: "",
    goal: "",
    prisms: [],
    beams: [],
    lenses: [],
    accepts_signals: [],
    llm_config: %{
      provider: :openai,
      model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000
    },
    memory: []
  )

  @type t ::
          record(:specter,
            id: String.t(),
            name: String.t(),
            description: String.t(),
            goal: String.t(),
            prisms: [Lux.Prism.t()],
            beams: [Lux.Beam.t()],
            lenses: [Lux.Lens.t()],
            accepts_signals: [Lux.Signal.t()],
            llm_config: map(),
            memory: list()
          )

  @callback think(t(), context :: map()) :: {:ok, [action]} | {:error, term()}
            when action: {module(), map()}

  @callback handle_signal(t(), Lux.Signal.t()) :: {:ok, [action]} | :ignore | {:error, term()}
            when action: {module(), map()}

  @callback reflect(t(), capability :: term()) :: {:ok, t()} | {:error, term()}

  @doc """
  Default implementation of think that uses LLM-based reasoning.
  """
  def think(specter(name: name, goal: goal, memory: memory) = specter, context) do
    prompt = """
    You are #{name}, an autonomous agent with the following goal:
    #{goal}

    Recent memory:
    #{format_memory(memory)}

    Current context:
    #{inspect(context)}

    Based on your goal and the current context, what actions should you take?
    Respond in the following JSON format:
    {
      "thoughts": "your reasoning process",
      "actions": [
        {
          "type": "prism|beam|lens",
          "name": "action_name",
          "params": {}
        }
      ]
    }
    """

    with {:ok, response} <- call_llm(prompt, specter) do
      parse_llm_response(response)
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Lux.Specter
      import Lux.Specter
      require Record

      # Default implementations that can be overridden

      @impl true
      def think(specter, context) do
        Lux.Specter.think(specter, context)
      end

      @impl true
      def handle_signal(_specter, _signal) do
        :ignore
      end

      @impl true
      def reflect(specter, _capability) do
        {:ok, specter}
      end

      defoverridable think: 2, handle_signal: 2, reflect: 2
    end
  end

  @doc """
  Creates a new specter from the given attributes
  """
  def new(attrs) when is_map(attrs) do
    specter(
      id: attrs[:id] || Lux.UUID.generate(),
      name: attrs[:name] || "Anonymous Specter",
      description: attrs[:description] || "",
      goal: attrs[:goal] || "",
      llm_config: Map.merge(default_llm_config(), attrs[:llm_config] || %{}),
      prisms: attrs[:prisms] || [],
      beams: attrs[:beams] || [],
      lenses: attrs[:lenses] || [],
      accepts_signals: attrs[:accepts_signals] || [],
      memory: []
    )
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  # Private helpers

  defp default_llm_config do
    %{
      provider: :openai,
      model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000
    }
  end

  defp format_memory(memory) do
    memory
    |> Enum.map(&inspect/1)
    |> Enum.join("\n")
  end

  defp call_llm(_prompt, specter(llm_config: _config)) do
    # TODO: Implement actual LLM call
    # This is a placeholder that should be replaced with actual LLM integration
    {:ok,
     %{
       "thoughts" => "I should gather data before making a decision",
       "actions" => [
         %{
           "type" => "lens",
           "name" => "gather_data",
           "params" => %{}
         }
       ]
     }}
  end

  defp parse_llm_response(%{"actions" => actions}) do
    parsed_actions =
      Enum.map(actions, fn
        %{"type" => "prism", "name" => name, "params" => params} ->
          {String.to_existing_atom("Elixir.#{name}"), params}

        %{"type" => "beam", "name" => name, "params" => params} ->
          {String.to_existing_atom("Elixir.#{name}"), params}

        %{"type" => "lens", "name" => name, "params" => params} ->
          {String.to_existing_atom("Elixir.#{name}"), params}
      end)

    {:ok, parsed_actions}
  end

  defp parse_llm_response(_), do: {:error, :invalid_llm_response}
end

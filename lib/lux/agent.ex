defmodule Lux.Agent do
  @moduledoc """
  A Agent defines an autonomous agent's capabilities, behaviors and goals.
  The actual execution and supervision is handled by the Lux runtime.

  Agents can be configured with different templates that provide specialized behaviors:
  - :company_agent - Adds company-specific signal handling
  - (other templates to be added)

  ## Example
      defmodule MyCompanyAgent do
        use Lux.Agent,
          template: :company_agent,
          template_opts: %{
            llm_config: %{temperature: 0.7}
          } do

          def init(opts) do
            {:ok, opts}
          end

          # Can override template functions if needed
          def handle_task_assignment(signal, context) do
            # Custom implementation
          end
        end
      end
  """

  alias Lux.LLM
  alias Lux.LLM.OpenAI.Config

  require Logger

  @type scheduled_beam :: {module(), String.t(), keyword()}
  @type collaboration_protocol :: :ask | :tell | :delegate | :request_review
  @type memory_config :: %{
          backend: module(),
          name: atom() | nil
        }

  # {module, interval_ms, input, opts}
  @type scheduled_action :: {module(), pos_integer(), map(), map()}

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
          llm_config: map(),
          memory_config: memory_config() | nil,
          memory_pid: pid() | nil,
          scheduled_actions: [scheduled_action()]
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
            memory_config: nil,
            memory_pid: nil,
            scheduled_actions: [],
            llm_config: %{
              provider: :openai,
              model: "gpt-4",
              temperature: 0.7
              # max_tokens: 1000
            }

  @callback chat(t(), message :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback handle_signal(t(), Lux.Signal.t()) :: {:ok, term()} | :ignore | {:error, term()}

  @callback new(attrs :: map()) :: t()

  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Lux.Agent

      use GenServer

      require Logger

      # First evaluate the user's block if provided
      unquote(opts[:do])

      @default_values %{
        module: __MODULE__
      }

      # Then inject template-specific functions
      case unquote(opts[:template]) do
        :company_agent ->
          # Inject company signal handler functions
          use Lux.Agent.Companies.SignalHandler

          # Store template options in module attribute at compile time
          @template_opts (
                           opts = unquote(opts[:template_opts])

                           cond do
                             is_nil(opts) -> %{}
                             is_list(opts) -> Map.new(opts)
                             is_map(opts) -> opts
                             true -> %{}
                           end
                         )

          @impl Lux.Agent
          def handle_signal(signal, context) do
            context = Map.merge(context, @template_opts)
            Lux.Agent.Companies.SignalHandler.DefaultImplementation.handle_signal(signal, context)
          end

        _ ->
          @template_opts %{}

          @impl Lux.Agent
          def handle_signal(_signal, _context) do
            :ignore
          end
      end

      @impl Lux.Agent
      def new(attrs) do
        @default_values
        |> Map.merge(attrs)
        |> Lux.Agent.new()
      end

      @impl Lux.Agent
      def chat(agent, message, opts \\ []) do
        Lux.Agent.chat(agent, message, opts)
      end

      # GenServer Client API
      def start_link(attrs \\ %{}) do
        agent = new(attrs)
        GenServer.start_link(__MODULE__, agent, name: get_name(agent))
      end

      def child_spec(opts) do
        %{
          id: {__MODULE__, opts[:name] || :default},
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 60_000
        }
      end

      defp get_name(%{name: name}) when is_binary(name), do: String.to_atom(name)
      defp get_name(%{name: nil}), do: __MODULE__
      defp get_name(%{name: name}) when is_atom(name), do: name

      def send_message(pid, message, opts \\ []) do
        timeout = opts[:timeout] || 120_000
        GenServer.call(pid, {:chat, message, opts}, timeout)
      end

      # GenServer Callbacks
      @impl GenServer
      def init(agent) do
        # Initialize memory if configured
        agent =
          case agent.memory_config do
            %{backend: backend} = config when not is_nil(backend) ->
              {:ok, pid} = backend.initialize(name: config[:name])
              %{agent | memory_pid: pid}

            _ ->
              agent
          end

        # Schedule initial runs for all scheduled actions
        for {module, interval_ms, input, opts} <- agent.scheduled_actions do
          name = opts[:name] || Lux.Agent.module_to_name(module)
          Lux.Agent.schedule_action(name, module, interval_ms, input, opts)
        end

        {:ok, agent}
      end

      @impl GenServer
      def handle_call({:chat, message, opts}, _from, agent) do
        case chat(agent, message, opts) do
          {:ok, response} = ok -> {:reply, ok, agent}
          {:error, _reason} = error -> {:reply, error, agent}
        end
      end

      @impl GenServer
      def handle_info(input, agent) do
        Lux.Agent.__handle_info__(input, agent)
      end

      @impl GenServer
      def terminate(_reason, %{memory_pid: pid}) when is_pid(pid) do
        Process.exit(pid, :normal)
        :ok
      end

      def terminate(_reason, _agent), do: :ok

      defoverridable new: 1, chat: 3, handle_signal: 2
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
      memory_config: Map.get(attrs, :memory_config),
      memory_pid: nil,
      llm_config:
        attrs
        |> Map.get(:llm_config, %{})
        |> then(fn
          %Config{} = config -> config
          config -> struct(Config, config)
        end),
      prisms: Map.get(attrs, :prisms, []),
      beams: Map.get(attrs, :beams, []),
      lenses: Map.get(attrs, :lenses, []),
      accepts_signals: Map.get(attrs, :accepts_signals, []),
      scheduled_actions: Map.get(attrs, :scheduled_actions, [])
    })
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  def handle_signal(agent, signal) do
    apply(agent.module, :handle_signal, [agent, signal])
  end

  def chat(agent, message, opts) do
    llm_config = build_llm_config(agent, opts)

    case LLM.call(message, agent.beams ++ agent.prisms, llm_config) do
      {:ok, %{payload: %{content: content}}} when is_map(content) ->
        store_interaction(agent, message, format_content(content), opts)
        {:ok, format_content(content)}

      {:ok, %{payload: %{content: content}}} when is_binary(content) ->
        store_interaction(agent, message, content, opts)
        {:ok, content}

      {:error, reason} ->
        {:error, reason}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, error["message"] || "Unknown error"}

      {:ok, %Lux.Signal{payload: %{tool_calls_results: tool_call_results}} = signal} ->
        store_interaction(agent, message, format_content(tool_call_results), opts)
        {:ok, signal}

      unexpected ->
        {:error, {:unexpected_response, unexpected}}
    end
  end

  # Private function to build LLM config with memory context if enabled
  defp build_llm_config(agent, opts) do
    if agent.memory_pid && Keyword.get(opts, :use_memory, false) do
      max_context = Keyword.get(opts, :max_memory_context, 5)
      {:ok, recent} = agent.memory_config.backend.recent(agent.memory_pid, max_context)

      # Convert memory entries to chat messages
      memory_messages =
        recent
        |> Enum.reverse()
        |> Enum.map(fn entry ->
          %{role: entry.metadata.role, content: entry.content}
        end)

      # Add memory context to existing messages or create new messages list
      Map.update(agent.llm_config, :messages, memory_messages, fn existing ->
        memory_messages ++ existing
      end)
    else
      agent.llm_config
    end
  end

  # Private function to store interactions in memory if enabled
  defp store_interaction(agent, user_message, assistant_response, opts) do
    if agent.memory_pid && Keyword.get(opts, :use_memory, false) do
      {:ok, _} =
        agent.memory_config.backend.add(
          agent.memory_pid,
          user_message,
          :interaction,
          %{role: :user}
        )

      {:ok, _} =
        agent.memory_config.backend.add(
          agent.memory_pid,
          assistant_response,
          :interaction,
          %{role: :assistant}
        )
    end
  end

  # Helper function to format map content into a readable string
  defp format_content(content) when is_map(content) do
    Enum.map_join(content, "\n", fn {k, v} -> "#{k}: #{format_value(v)}" end)
  end

  defp format_content(result) when is_list(result) do
    Enum.map_join(result, "\n", fn element -> format_content(element) end)
  end

  defp format_value(value) when is_list(value) do
    Enum.map_join(value, ", ", &format_value/1)
  end

  defp format_value(value) when is_map(value), do: format_content(value)
  defp format_value(value), do: to_string(value)

  def schedule_action(name, module, interval_ms, input, opts) do
    Process.send_after(
      self(),
      {:run_scheduled_action, name, module, interval_ms, input, opts},
      interval_ms
    )
  end

  def module_to_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> String.downcase()
  end

  def beam?(module) when is_atom(module) do
    function_exported?(module, :steps, 0) and function_exported?(module, :run, 2)
  end

  def beam?(_), do: false

  def prism?(module) when is_atom(module) do
    function_exported?(module, :handler, 2)
  end

  def prism?(_), do: false

  # Implements the logic for the agent process based on Genservers.
  # Needed for better testability and formatting and readability of the __using__ block above.
  # Consider these internal functions.

  def __handle_info__({:signal, signal}, agent) do
    _ = handle_signal(agent, signal)
    {:noreply, agent}
  end

  def __handle_info__({:run_scheduled_action, name, module, interval_ms, input, opts}, agent) do
    timeout = opts[:timeout] || 60_000

    # Execute the action based on whether it's a Prism or Beam
    Task.Supervisor.async_nolink(
      Lux.ScheduledTasksSupervisor,
      fn ->
        try do
          result =
            case {Lux.Agent.prism?(module), Lux.Agent.beam?(module)} do
              {true, false} ->
                module.handler(input, agent)

              {false, true} ->
                module.run(input, agent)

              _ ->
                {:error, :invalid_module}
            end

          case result do
            {:ok, _} ->
              Logger.info("Scheduled action #{name} completed successfully")

            {:error, reason} ->
              Logger.warning("Scheduled action #{name} failed: #{inspect(reason)}")
          end
        catch
          kind, reason ->
            Logger.error("Scheduled action #{name} crashed: #{inspect({kind, reason})}")
        end
      end,
      timeout: timeout
    )

    # Schedule the next run
    Lux.Agent.schedule_action(name, module, interval_ms, input, opts)

    {:noreply, agent}
  end

  # to handle result from Task.Supervisor.async_nolink
  def __handle_info__({_ref, _result}, agent) do
    {:noreply, agent}
  end

  # to handle when the Task.Supervisor.async_nolink process is down without bringing down the agent
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, agent) do
    {:noreply, agent}
  end

  # implements the access protocol for this struct...
  def fetch(agent, key) do
    Map.get(agent, key)
  end
end

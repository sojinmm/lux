defmodule Lux.Company.ExecutionEngine.ObjectiveProcess do
  @moduledoc """
  A GenServer process that manages the execution of a single objective.

  This module is responsible for:
  - Managing the state machine of an objective's execution
  - Tracking progress and current step
  - Handling state transitions
  - Managing errors and failures
  - Coordinating with the company process
  """

  use GenServer
  require Logger

  # State machine: pending -> initializing -> in_progress -> completed
  #                      \-> failed
  #                      \-> cancelled

  @type state :: %{
    id: String.t(),
    objective: Lux.Company.Objective.t(),
    company_pid: pid(),
    input: map(),
    status: :pending | :initializing | :in_progress | :completed | :failed | :cancelled,
    current_step: integer(),
    progress: integer(),
    error: term() | nil,
    started_at: DateTime.t() | nil,
    completed_at: DateTime.t() | nil,
    artifacts: map()
  }

  # Client API

  @doc """
  Starts a new ObjectiveProcess with the given options.

  Required options:
  - :objective_id - Unique identifier for this objective process
  - :objective - The Objective struct to execute
  - :company_pid - PID of the company process
  - :input - Map of input values for the objective
  - :registry - The registry to register this process with
  """
  def start_link(opts) do
    objective_id = Keyword.fetch!(opts, :objective_id)
    registry = Keyword.fetch!(opts, :registry)
    Logger.debug("Starting ObjectiveProcess #{objective_id} with registry #{inspect(registry)}")
    Logger.debug("Start options: #{inspect(opts)}")

    case Process.whereis(registry) do
      nil ->
        Logger.error("Registry #{inspect(registry)} not found!")
        {:error, :registry_not_found}
      registry_pid ->
        Logger.debug("Found registry at #{inspect(registry_pid)}")
        name = via_tuple(objective_id, registry)
        Logger.debug("Registering with name: #{inspect(name)}")
        GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Initialize the objective process"
  def initialize(pid), do: GenServer.call(pid, :initialize)

  @doc "Start executing the objective"
  def start(pid), do: GenServer.call(pid, :start)

  @doc "Mark the objective as completed"
  def complete(pid), do: GenServer.call(pid, :complete)

  @doc "Mark the objective as failed with the given reason"
  def fail(pid, reason), do: GenServer.call(pid, {:fail, reason})

  @doc "Cancel the objective execution"
  def cancel(pid), do: GenServer.call(pid, :cancel)

  @doc "Update the progress percentage (0-100)"
  def update_progress(pid, progress) when is_integer(progress) do
    if progress >= 0 and progress <= 100 do
      GenServer.call(pid, {:update_progress, progress})
    else
      {:error, :invalid_progress}
    end
  end

  @doc "Set the current step being executed"
  def set_current_step(pid, step), do: GenServer.call(pid, {:set_current_step, step})

  @doc "Add an error message to the objective's error list"
  def add_error(pid, error), do: GenServer.call(pid, {:add_error, error})

  # Server callbacks

  @impl true
  def init(opts) do
    Logger.debug("Initializing ObjectiveProcess with opts: #{inspect(opts)}")

    state = %{
      id: Keyword.fetch!(opts, :objective_id),
      objective: Keyword.fetch!(opts, :objective),
      company_pid: Keyword.fetch!(opts, :company_pid),
      input: Keyword.fetch!(opts, :input),
      registry: Keyword.fetch!(opts, :registry),
      status: :pending,
      current_step: nil,
      progress: 0,
      error: nil,
      started_at: nil,
      completed_at: nil,
      artifacts: %{}
    }

    Logger.debug("Initial state: #{inspect(state)}")
    {:ok, state}
  end

  @impl true
  def handle_call(:initialize, _from, %{status: :pending} = state) do
    Logger.debug("Initializing objective #{state.id}")
    new_state = %{state | status: :initializing}
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:start, _from, %{status: :initializing} = state) do
    Logger.debug("Starting objective #{state.id}")
    new_state = %{state |
      status: :in_progress,
      started_at: DateTime.utc_now()
    }
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:complete, _from, %{status: :in_progress} = state) do
    Logger.debug("Completing objective #{state.id}")
    new_state = %{state |
      status: :completed,
      progress: 100,
      completed_at: DateTime.utc_now()
    }
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:fail, reason}, _from, %{status: :in_progress} = state) do
    Logger.debug("Failing objective #{state.id} with reason: #{inspect(reason)}")
    new_state = %{state |
      status: :failed,
      error: reason,
      completed_at: DateTime.utc_now()
    }
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:cancel, _from, %{status: :in_progress} = state) do
    Logger.debug("Cancelling objective #{state.id}")
    new_state = %{state |
      status: :cancelled,
      completed_at: DateTime.utc_now()
    }
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:update_progress, progress}, _from, %{status: :in_progress} = state) do
    Logger.debug("Updating progress for objective #{state.id} to #{progress}%")
    new_state = %{state | progress: progress}
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:set_current_step, step}, _from, %{status: :in_progress, objective: objective} = state) do
    Logger.debug("Setting current step for objective #{state.id} to: #{inspect(step)}")
    if step in objective.steps do
      new_state = %{state | current_step: step}
      notify_company(new_state)
      {:reply, :ok, new_state}
    else
      Logger.warning("Invalid step #{inspect(step)} for objective #{state.id}")
      {:reply, {:error, :invalid_step}, state}
    end
  end

  def handle_call({:add_error, error}, _from, state) do
    Logger.debug("Adding error for objective #{state.id}: #{inspect(error)}")
    new_state = %{state | error: error}
    notify_company(new_state)
    {:reply, :ok, new_state}
  end

  # Invalid state transitions
  def handle_call(action, _from, state) do
    Logger.warning("Invalid state transition: #{inspect(action)} in state #{inspect(state.status)}")
    {:reply, {:error, :invalid_state_transition}, state}
  end

  @impl true
  def handle_info(:initialize, state) do
    Logger.debug("Received :initialize message in state #{inspect(state.status)}")
    case state.status do
      :pending ->
        Logger.debug("Auto-initializing objective #{state.id}")
        new_state = %{state | status: :initializing}
        notify_company(new_state)
        {:noreply, new_state}
      _ ->
        Logger.warning("Ignoring :initialize message in #{state.status} state")
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.warning("Received unexpected message: #{inspect(msg)} in state #{inspect(state.status)}")
    {:noreply, state}
  end

  # Private functions

  defp via_tuple(objective_id, registry) do
    {:via, Registry, {registry, objective_id}}
  end

  defp notify_company(state) do
    Logger.debug("Notifying company of state update for objective #{state.id}")
    Logger.debug("Current state: #{inspect(state)}")
    send(state.company_pid, {:objective_update, state.id, state})
  end
end

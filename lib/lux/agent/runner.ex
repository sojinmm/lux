defmodule Lux.Agent.Runner do
  @moduledoc """
  GenServer implementation for running individual Agent processes.
  Handles the agent's lifecycle, scheduled tasks, and reflection process.
  """

  use GenServer

  # Client API

  def start_link(%Lux.Agent{} = agent) do
    GenServer.start_link(__MODULE__, agent)
  end

  def get_agent(pid) do
    GenServer.call(pid, :get_agent)
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def schedule_beam(pid, beam_module, cron_expression, opts \\ []) do
    GenServer.call(pid, {:schedule_beam, beam_module, cron_expression, opts})
  end

  def unschedule_beam(pid, beam_module) do
    GenServer.call(pid, {:unschedule_beam, beam_module})
  end

  def handle_signal(pid, signal) do
    GenServer.cast(pid, {:handle_signal, signal})
  end

  def trigger_learning(pid) do
    GenServer.cast(pid, :learn)
  end

  def chat(pid, message, opts \\ []) do
    GenServer.call(pid, {:chat, message, opts})
  end

  # Server Callbacks

  @impl true
  def init(%Lux.Agent{} = agent) do
    # Schedule initial reflection cycle
    schedule_reflection(agent.reflection_interval)
    # Schedule beam check
    schedule_beam_check()
    # Schedule periodic learning
    schedule_learning()

    {:ok, %{agent: agent, context: %{}}}
  end

  @impl true
  def handle_call(:get_agent, _from, %{agent: agent} = state) do
    {:reply, {:ok, agent, self()}, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call(
        {:schedule_beam, beam_module, cron_expression, opts},
        _from,
        %{agent: agent} = state
      ) do
    case Lux.Agent.schedule_beam(agent, beam_module, cron_expression, opts) do
      {:ok, updated_agent} ->
        {:reply, :ok, %{state | agent: updated_agent}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:unschedule_beam, beam_module}, _from, %{agent: agent} = state) do
    case Lux.Agent.unschedule_beam(agent, beam_module) do
      {:ok, updated_agent} ->
        {:reply, :ok, %{state | agent: updated_agent}}
    end
  end

  def handle_call({:chat, message, opts}, _from, %{agent: agent} = state) do
    case Lux.Agent.chat(agent, message, opts) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:handle_signal, signal}, %{agent: agent} = state) do
    case Lux.Agent.handle_signal(agent, signal) do
      {:ok, actions} ->
        execute_actions(actions, state)
        {:noreply, state}

      :ignore ->
        {:noreply, state}

      {:error, _reason} ->
        # Log error but don't crash
        {:noreply, state}
    end
  end

  def handle_cast(:learn, %{agent: agent} = state) do
    # Update reflection through learning
    updated_reflection = Lux.Reflection.learn(agent.reflection)
    updated_agent = %{agent | reflection: updated_reflection}

    {:noreply, %{state | agent: updated_agent}}
  end

  @impl true
  def handle_info(:reflect, %{agent: agent} = state) do
    # Execute reflection cycle
    case Lux.Agent.reflect(agent, state.context) do
      {:ok, results, updated_agent} ->
        # Update context with results
        new_context = update_context(state.context, results)
        # Schedule next reflection cycle
        schedule_reflection(updated_agent.reflection_interval)
        {:noreply, %{state | agent: updated_agent, context: new_context}}

      {:error, _reason, updated_agent} ->
        # Log error but don't crash
        schedule_reflection(updated_agent.reflection_interval)
        {:noreply, %{state | agent: updated_agent}}
    end
  end

  def handle_info(:check_beams, %{agent: agent} = state) do
    # Get and execute due beams
    due_beams = Lux.Agent.get_due_beams(agent)

    Enum.each(due_beams, fn {beam_module, _cron, opts} ->
      Task.start(fn ->
        beam_module.run(opts[:input] || %{}, %{agent: agent})
      end)
    end)

    # Schedule next check
    schedule_beam_check()
    {:noreply, state}
  end

  def handle_info(:trigger_learning, state) do
    # Trigger learning process
    handle_cast(:learn, state)
    # Schedule next learning cycle
    schedule_learning()
    {:noreply, state}
  end

  # Private Helpers

  defp schedule_reflection(interval) do
    Process.send_after(self(), :reflect, interval)
  end

  defp schedule_beam_check do
    # Check beams every minute
    Process.send_after(self(), :check_beams, 60_000)
  end

  defp schedule_learning do
    # Trigger learning every hour
    Process.send_after(self(), :trigger_learning, 60 * 60 * 1000)
  end

  defp update_context(context, results) do
    Map.merge(context, %{
      last_reflection_results: results,
      last_reflection_time: DateTime.utc_now()
    })
  end

  defp execute_actions(actions, state) do
    Enum.each(actions, fn {module, params} ->
      Task.start(fn ->
        module.run(params, %{agent: state.agent})
      end)
    end)
  end
end

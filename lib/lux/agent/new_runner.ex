defmodule Lux.Agent.NewRunner do
  @moduledoc """
  A simplified agent runner focused on chat functionality.
  This runner is designed to be a clean implementation that can be tested and evolved progressively.
  """

  use GenServer

  # Client API

  @doc """
  Starts a new agent runner process.
  """
  def start_link(%Lux.Agent{} = agent) do
    GenServer.start_link(__MODULE__, agent)
  end

  @doc """
  Sends a chat message to the agent and waits for a response.
  """
  def chat(pid, message, opts \\ [], timeout \\ 30_000) do
    GenServer.call(pid, {:chat, message, opts}, timeout)
  end

  @doc """
  Gets the current agent state.
  """
  def get_agent(pid) do
    GenServer.call(pid, :get_agent)
  end

  # Server Callbacks

  @impl true
  def init(%Lux.Agent{} = agent) do
    {:ok, %{agent: agent}}
  end

  @impl true
  def handle_call(:get_agent, _from, %{agent: agent} = state) do
    {:reply, {:ok, agent}, state}
  end

  @impl true
  def handle_call({:chat, message, opts}, _from, %{agent: agent} = state) do
    case Lux.Agent.chat(agent, message, opts) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end

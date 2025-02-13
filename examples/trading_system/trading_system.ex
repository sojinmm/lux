defmodule Examples.TradingSystem do
  @moduledoc """
  Simple interface for running the trading system.
  """

  alias Lux.Agents.MarketResearcher
  alias Lux.Agents.RiskManager
  alias Lux.AgentHub
  alias Lux.Signal
  alias Lux.Signal.Router.Local

  require Logger

  @doc """
  Runs one iteration of market analysis and trading.
  """
  def run do
    # Start the agent hub
    {:ok, hub} = AgentHub.start_link(name: :trading_hub)

    # Start the signal router
    {:ok, router} = Local.start_link(name: :trading_router)

    # Start both agents
    {:ok, researcher_pid} = MarketResearcher.start_link()
    {:ok, risk_manager_pid} = RiskManager.start_link()

    # Get agent states
    researcher = :sys.get_state(researcher_pid)
    risk_manager = :sys.get_state(risk_manager_pid)

    # Register agents with their capabilities
    :ok = AgentHub.register(hub, researcher, researcher_pid, [:market_research, :analysis])
    :ok = AgentHub.register(hub, risk_manager, risk_manager_pid, [:risk_management])

    # Example market conditions (replace with real data)
    market_conditions = %{
      "ETH" => %{
        "price" => 2800.0,
        "24h_volume" => 1_000_000,
        "volatility" => 0.15
      }
    }

    # Get trade proposal from researcher and send to risk manager
    with {:ok, signal} <- MarketResearcher.propose_trade(researcher_pid, market_conditions) do
      # Create a signal to send to the risk manager
      trade_signal = Signal.new(%{
        payload: signal,
        sender: researcher.id,
        recipient: risk_manager.id
      })

      signal_id = trade_signal.id

      # Subscribe to signal delivery events
      :ok = Local.subscribe(signal_id, name: router)

      # Update researcher status to busy while processing
      :ok = AgentHub.update_status(hub, researcher.id, :busy)

      # Route the signal through the local router
      :ok = Local.route(trade_signal, name: router, hub: hub)

      # Wait for signal delivery confirmation
      receive do
        {:signal_delivered, ^signal_id} ->
          Logger.info("Trade signal delivered successfully")
          :ok = AgentHub.update_status(hub, researcher.id, :available)

        {:signal_failed, ^signal_id, reason} ->
          Logger.error("Failed to deliver trade signal: #{inspect(reason)}")
          :ok = AgentHub.update_status(hub, researcher.id, :available)
      after
        5000 ->
          Logger.error("Timeout waiting for signal delivery")
          :ok = AgentHub.update_status(hub, researcher.id, :available)
          {:error, :timeout}
      end
    end
  end
end

defmodule Examples.TradingSystem do
  @moduledoc """
  Simple interface for running the trading system.
  """

  alias Lux.Agents.MarketResearcher
  alias Lux.Agents.RiskManager

  require Logger

  @doc """
  Runs one iteration of market analysis and trading.
  """
  def run do
    # Start both agents
    {:ok, researcher} = MarketResearcher.start_link()
    {:ok, risk_manager} = RiskManager.start_link()

    # Example market conditions (replace with real data)
    market_conditions = %{
      "ETH" => %{
        "price" => 2800.0,
        "24h_volume" => 1_000_000,
        "volatility" => 0.15
      }
    }

    # Get trade proposal from researcher
    with {:ok, string_trade_proposal} <-
           MarketResearcher.propose_trade(researcher, market_conditions),
         {:ok, trade_proposal} <- Jason.decode(string_trade_proposal),
         {:ok, result} <- RiskManager.evaluate_trade(risk_manager, trade_proposal) do
      Logger.info("Trading iteration completed")
      Logger.info("Trade proposal: #{inspect(trade_proposal)}")
      Logger.info("Result: #{inspect(result)}")
      {:ok, result}
    end
  end
end

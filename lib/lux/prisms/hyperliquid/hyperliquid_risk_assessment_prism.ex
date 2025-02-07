defmodule Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism do
  @moduledoc """
  A prism that calculates risk metrics for a proposed Hyperliquid trade.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism.run(%{
      ...>   portfolio: hyperliquid_portfolio,
      ...>   market_data: hyperliquid_market_data,
      ...>   proposed_trade: %{
      ...>     coin: "ETH",
      ...>     sz: 0.1,
      ...>     limit_px: 2800.0,
      ...>     is_buy: true
      ...>   }
      ...> })
      {:ok, %{
        position_size_ratio: 0.15,
        leverage: 2.0,
        portfolio_concentration: 0.25,
        liquidation_risk: 0.05,
        unrealized_pnl: 0.1
      }}
  """

  use Lux.Prism,
    name: "Hyperliquid Risk Assessment",
    description: "Calculates risk metrics for a proposed trade",
    input_schema: %{
      type: :object,
      properties: %{
        portfolio: %{type: :object},
        market_data: %{type: :object},
        proposed_trade: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            sz: %{type: :number},
            limit_px: %{type: :number},
            is_buy: %{type: :boolean}
          },
          required: ["coin", "sz", "limit_px", "is_buy"]
        }
      },
      required: ["portfolio", "market_data", "proposed_trade"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        position_size_ratio: %{type: :number},
        leverage: %{type: :number},
        portfolio_concentration: %{type: :number},
        liquidation_risk: %{type: :number},
        unrealized_pnl: %{type: :number}
      },
      required: [
        "position_size_ratio",
        "leverage",
        "portfolio_concentration",
        "liquidation_risk",
        "unrealized_pnl"
      ]
    }

  require Logger
  import Lux.Python

  def handler(%{portfolio: portfolio, market_data: prices, proposed_trade: trade} = input, ctx) do
    python_result =
      python variables: %{
               portfolio: portfolio,
               market_data: prices,
               trade: trade
             } do
        ~PY"""
        import json

        def log_debug(msg, data=None):
            '''Helper to print debug info'''
            print(f"DEBUG: {msg}")
            if data:
                print(f"DATA: {json.dumps(data, indent=2)}")

        log_debug("Input data:", {
            "portfolio": portfolio,
            # "market_data": market_data,
            "trade": trade
        })

        def find_position(portfolio, coin):
            '''Find current position for the given coin'''
            log_debug(f"Finding position for {coin}", {
                "portfolio_positions": portfolio.get("assetPositions", [])
            })
            for pos in portfolio.get("assetPositions", []):
                if pos["position"]["coin"] == coin:
                    return pos
            return None

        def calculate_position_size_ratio(trade, market_price, margin_summary):
            '''Calculate position size as percentage of portfolio'''
            log_debug("Calculating position size ratio", {
                "trade": trade,
                "market_price": market_price,
                "margin_summary": margin_summary
            })
            trade_value = float(trade["sz"]) * float(market_price)
            account_value = float(margin_summary["accountValue"])
            return trade_value / account_value

        def calculate_leverage(portfolio, trade, market_price):
            '''Calculate current leverage including the new trade'''
            log_debug("Calculating leverage", {
                "portfolio": portfolio,
                "trade": trade,
                "market_price": market_price
            })
            margin_summary = portfolio["crossMarginSummary"]
            current_leverage = float(margin_summary["totalNtlPos"]) / float(margin_summary["accountValue"])

            trade_value = float(trade["sz"]) * float(market_price)
            account_value = float(margin_summary["accountValue"])

            return (trade_value + current_leverage * account_value) / account_value

        def calculate_concentration(position, margin_summary):
            '''Calculate portfolio concentration for this asset'''
            log_debug("Calculating concentration", {
                "position": position,
                "margin_summary": margin_summary
            })
            if not position:
                return 0.0

            position_value = float(position["position"]["positionValue"])
            account_value = float(margin_summary["accountValue"])
            return position_value / account_value

        def calculate_liquidation_risk(position, market_price):
            '''Calculate risk of liquidation'''
            log_debug("Calculating liquidation risk", {
                "position": position,
                "market_price": market_price
            })
            if not position:
                return 0.0

            liq_price = position["position"].get("liquidationPx")
            if liq_price is None or liq_price == "nil":  # Handle both Python None and Elixir nil
                return 0.0

            current_price = float(market_price)
            return abs(float(liq_price) - current_price) / current_price

        def calculate_unrealized_pnl(position):
            '''Calculate unrealized PnL'''
            log_debug("Calculating unrealized PnL", {
                "position": position
            })
            if not position:
                return 0.0
            return float(position["position"]["returnOnEquity"])

        # Main risk calculation
        log_debug("Starting main risk calculation")

        current_position = find_position(portfolio, trade["coin"])
        log_debug("Found position:", current_position)

        log_debug("Getting market price", {
            # "market_data": market_data,
            "coin": trade["coin"]
        })
        market_price = market_data[trade["coin"]]["markPx"]
        log_debug(f"Market price: {market_price}")

        margin_summary = portfolio["crossMarginSummary"]
        log_debug("Margin summary:", margin_summary)

        metrics = {
            "position_size_ratio": calculate_position_size_ratio(trade, market_price, margin_summary),
            "leverage": calculate_leverage(portfolio, trade, market_price),
            "portfolio_concentration": calculate_concentration(current_position, margin_summary),
            "liquidation_risk": calculate_liquidation_risk(current_position, market_price),
            "unrealized_pnl": calculate_unrealized_pnl(current_position)
        }

        log_debug("Final metrics:", metrics)
        metrics
        """
      end

    case python_result do
      %{"error" => error} ->
        Logger.error("Risk assessment failed: #{inspect(error)}")
        {:error, error}
      metrics when is_map(metrics) ->
        Logger.info("Risk assessment completed", metrics: metrics)
        {:ok, metrics}
    end
  end
end

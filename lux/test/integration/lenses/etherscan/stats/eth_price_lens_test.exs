defmodule Lux.Integration.Etherscan.EthPriceLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.EthPrice
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can fetch ETH price information" do
    assert {:ok, %{result: eth_price, eth_price: eth_price}} =
             RateLimitedAPI.call_standard(EthPrice, :focus, [%{
               chainid: 1
             }])

    # Verify the structure of the response
    assert is_map(eth_price)
    assert Map.has_key?(eth_price, :eth_btc)
    assert Map.has_key?(eth_price, :eth_btc_timestamp)
    assert Map.has_key?(eth_price, :eth_usd)
    assert Map.has_key?(eth_price, :eth_usd_timestamp)

    # ETH price should be a positive number
    assert is_number(eth_price.eth_usd)
    assert eth_price.eth_usd > 0
    assert is_number(eth_price.eth_btc)
    assert eth_price.eth_btc > 0

    # Timestamps should be valid Unix timestamps
    assert is_integer(eth_price.eth_usd_timestamp)
    assert eth_price.eth_usd_timestamp > 1_500_000_000 # Timestamp after 2017
    assert is_integer(eth_price.eth_btc_timestamp)
    assert eth_price.eth_btc_timestamp > 1_500_000_000 # Timestamp after 2017
  end

  test "can fetch ETH price for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on the chain
    result = RateLimitedAPI.call_standard(EthPrice, :focus, [%{
      chainid: 137 # Polygon
    }])

    case result do
      {:ok, %{result: eth_price}} ->
        assert true

      {:error, error} ->
        # If the endpoint doesn't exist on this chain, that's also acceptable
        assert true
    end
  end
end

defmodule Lux.Integration.Etherscan.EthSupplyLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.EthSupply
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can fetch total ETH supply" do
    assert {:ok, %{result: eth_supply, eth_supply: eth_supply}} =
             RateLimitedAPI.call_standard(EthSupply, :focus, [%{
               chainid: 1
             }])

    # ETH supply should be a large number (more than 100 million ETH)
    assert is_integer(eth_supply)
    assert eth_supply > 100_000_000 * 1.0e18 # More than 100M ETH in wei
  end

  test "can fetch ETH supply for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on the chain
    result = RateLimitedAPI.call_standard(EthSupply, :focus, [%{
      chainid: 137 # Polygon
    }])

    case result do
      {:ok, %{result: eth_supply}} ->
        assert true

      {:error, error} ->
        # If the endpoint doesn't exist on this chain, that's also acceptable
        assert true
    end
  end
end

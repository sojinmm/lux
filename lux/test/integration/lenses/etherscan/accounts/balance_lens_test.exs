defmodule Lux.Integration.Etherscan.BalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.Balance
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Vitalik's address
  @vitalik "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  # Ethereum Foundation address
  @eth_foundation "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can fetch ETH balance for a single address" do
    # Use RateLimitedAPI instead of calling Balance.focus directly
    assert {:ok, %{result: balance}} =
             RateLimitedAPI.call_standard(Balance, :focus, [%{
               address: @vitalik,
               chainid: 1
             }])

    # Convert balance from wei to ether for easier validation
    balance_in_eth = String.to_integer(balance) / 1.0e18

    # Vitalik should have some ETH (more than 0)
    assert is_binary(balance)
    assert balance_in_eth > 0
  end

  test "can fetch ETH balance for a different address" do
    # Use RateLimitedAPI instead of calling Balance.focus directly
    assert {:ok, %{result: balance}} =
             RateLimitedAPI.call_standard(Balance, :focus, [%{
               address: @eth_foundation,
               chainid: 1
             }])

    # Convert balance from wei to ether for easier validation
    balance_in_eth = String.to_integer(balance) / 1.0e18

    # Ethereum Foundation should have some ETH (more than 0)
    assert is_binary(balance)
    assert balance_in_eth > 0
  end

  test "can specify a different tag (block parameter)" do
    # Use RateLimitedAPI instead of calling Balance.focus directly
    assert {:ok, %{result: _balance}} =
             RateLimitedAPI.call_standard(Balance, :focus, [%{
               address: @vitalik,
               chainid: 1,
               tag: "latest"
             }])
  end
end

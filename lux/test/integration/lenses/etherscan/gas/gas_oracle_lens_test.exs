defmodule Lux.Integration.Etherscan.GasOracleLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.GasOracle
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can fetch current gas prices" do
    # Always include chainid parameter for v2 API
    assert {:ok, %{result: gas_info}} = RateLimitedAPI.call_standard(GasOracle, :focus, [%{chainid: 1}])

    # Verify the gas info structure
    assert is_map(gas_info)

    # Check that the gas info contains the expected fields
    assert Map.has_key?(gas_info, :safe_gas_price)
    assert Map.has_key?(gas_info, :propose_gas_price)
    assert Map.has_key?(gas_info, :fast_gas_price)
    assert Map.has_key?(gas_info, :suggest_base_fee)
    assert Map.has_key?(gas_info, :gas_used_ratio)
    assert Map.has_key?(gas_info, :last_block)

    # The gas prices should be numeric values
    assert is_number(gas_info.safe_gas_price)
    assert is_number(gas_info.propose_gas_price)
    assert is_number(gas_info.fast_gas_price)
    assert is_number(gas_info.suggest_base_fee)

    # The last block should be an integer
    assert is_integer(gas_info.last_block)
  end

  test "can fetch gas prices for a specific chain" do
    # Using Ethereum mainnet (chainid: 1)
    assert {:ok, %{result: gas_info}} = RateLimitedAPI.call_standard(GasOracle, :focus, [%{chainid: 1}])

    # Verify the gas info structure
    assert is_map(gas_info)

    # Check that the gas info contains the expected fields
    assert Map.has_key?(gas_info, :safe_gas_price)
    assert Map.has_key?(gas_info, :propose_gas_price)
    assert Map.has_key?(gas_info, :fast_gas_price)
    assert Map.has_key?(gas_info, :suggest_base_fee)
    assert Map.has_key?(gas_info, :gas_used_ratio)
    assert Map.has_key?(gas_info, :last_block)

    # The gas prices should be numeric values
    assert is_number(gas_info.safe_gas_price)
    assert is_number(gas_info.propose_gas_price)
    assert is_number(gas_info.fast_gas_price)
    assert is_number(gas_info.suggest_base_fee)

    # The last block should be an integer
    assert is_integer(gas_info.last_block)
  end
end

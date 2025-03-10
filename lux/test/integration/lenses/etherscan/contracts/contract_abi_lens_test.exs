defmodule Lux.Integration.Etherscan.ContractAbiLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractAbi
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # The DAO contract address (verified contract from the example in the documentation)
  @contract_address "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
  # Another verified contract (Uniswap V2 Router)
  @uniswap_router "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can fetch ABI for a verified contract" do
    assert {:ok, %{result: abi}} =
             RateLimitedAPI.call_standard(ContractAbi, :focus, [%{
               address: @contract_address,
               chainid: 1
             }])

    # Verify the ABI structure
    assert is_list(abi)

    # Check that the ABI contains function definitions
    assert Enum.any?(abi, fn item ->
      is_map(item) && Map.has_key?(item, "type")
    end)

    # Log some information about the ABI for informational purposes
    function_count = Enum.count(abi, fn item ->
      is_map(item) && Map.get(item, "type") == "function"
    end)
    event_count = Enum.count(abi, fn item ->
      is_map(item) && Map.get(item, "type") == "event"
    end)
  end

  test "can fetch ABI for another verified contract" do
    assert {:ok, %{result: abi}} =
             RateLimitedAPI.call_standard(ContractAbi, :focus, [%{
               address: @uniswap_router,
               chainid: 1
             }])

    # Verify the ABI structure
    assert is_list(abi)

    # Check that the ABI contains function definitions
    assert Enum.any?(abi, fn item ->
      is_map(item) && Map.has_key?(item, "type")
    end)

    # Log some information about the ABI for informational purposes
    function_count = Enum.count(abi, fn item ->
      is_map(item) && Map.get(item, "type") == "function"
    end)
  end
end

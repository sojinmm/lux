defmodule Lux.Integration.Etherscan.TokenSupplyLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenSupply
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Check if the API key is a Pro key by making a test request
    result = RateLimitedAPI.call_standard(TokenSupply, :focus, [%{
      contractaddress: @token_contract,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch total supply for an ERC-20 token" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      assert {:ok, %{result: supply, token_supply: supply}} =
               RateLimitedAPI.call_standard(TokenSupply, :focus, [%{
                 contractaddress: @token_contract,
                 chainid: 1
               }])

      # Verify the supply is a valid string representing a number
      assert is_binary(supply)
      {supply_value, _} = Integer.parse(supply)
      assert supply_value > 0
    end
  end
end

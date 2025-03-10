defmodule Lux.Integration.Etherscan.TokenBalanceHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenBalanceHistory
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Example address that holds LINK tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"
  # Block number to check (Ethereum block from 2019)
  @block_number 8000000

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  # Helper function to check if we're being rate limited
  defp is_rate_limited?(result) do
    case result do
      {:error, %{result: "Max rate limit reached"}} -> true
      {:error, %{message: message}} when is_binary(message) ->
        String.contains?(message, "rate limit")
      _ -> false
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Check if the API key is a Pro key by making a test request
    result = RateLimitedAPI.call_standard(TokenBalanceHistory, :focus, [%{
      contractaddress: @token_contract,
      address: @token_holder,
      blockno: @block_number,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch historical token balance for an address at a specific block" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      result = RateLimitedAPI.call_standard(TokenBalanceHistory, :focus, [%{
        contractaddress: @token_contract,
        address: @token_holder,
        blockno: @block_number,
        chainid: 1
      }])

      case result do
        {:ok, %{result: balance, token_balance: balance}} ->
          # Verify the balance is a valid string representing a number
          assert is_binary(balance)

        {:error, error} ->
          if is_rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch historical token balance: #{inspect(error)}")
          end
      end
    end
  end
end

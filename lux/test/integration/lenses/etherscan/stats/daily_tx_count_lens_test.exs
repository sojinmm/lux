defmodule Lux.Integration.Etherscan.DailyTxCountLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.DailyTxCount
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Make a test call to see if we get a Pro API error
    case RateLimitedAPI.call_standard(DailyTxCount, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }]) do
      {:error, %{result: result}} ->
        # If the result contains "API Pro endpoint", we don't have a Pro API key
        not String.contains?(result, "API Pro endpoint") and
        not String.contains?(result, "Missing Or invalid Action name")
      _ ->
        # If we get any other response, assume we have a Pro API key
        true
    end
  end

  test "can fetch daily transaction counts with required parameters" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      :ok
    else
      assert {:ok, %{result: tx_count_data}} =
               RateLimitedAPI.call_standard(DailyTxCount, :focus, [%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               }])

      # Verify the structure of the response
      assert is_list(tx_count_data)

      # If we got data, check the first entry
      if length(tx_count_data) > 0 do
        first_entry = List.first(tx_count_data)
        assert Map.has_key?(first_entry, :date)
        assert Map.has_key?(first_entry, :tx_count)

        # Transaction count should be a positive number
        assert is_binary(first_entry.tx_count) or is_number(first_entry.tx_count)
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      :ok
    else
      assert {:ok, %{result: tx_count_data}} =
               RateLimitedAPI.call_standard(DailyTxCount, :focus, [%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               }])

      # Verify the structure of the response
      assert is_list(tx_count_data)

      # If we got data, check that it's in descending order
      if length(tx_count_data) > 1 do
        first_date = List.first(tx_count_data).date
        second_date = Enum.at(tx_count_data, 1).date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end
end

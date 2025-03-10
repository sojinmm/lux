defmodule Lux.Integration.Etherscan.ChainSizeLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.ChainSize
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

  test "can fetch chain size data with required parameters" do
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }])

    case result do
      {:ok, %{result: chain_size_data, chain_size: chain_size_data}} ->
        # Verify the structure of the response
        assert is_list(chain_size_data)

        # If we got data, check the first entry
        if length(chain_size_data) > 0 do
          first_entry = List.first(chain_size_data)
          assert Map.has_key?(first_entry, :utc_date)
          assert Map.has_key?(first_entry, :block_number)
          assert Map.has_key?(first_entry, :chain_size_bytes)

          # Chain size should be a large number (more than 100 GB in bytes)
          assert is_integer(first_entry.chain_size_bytes)
          assert first_entry.chain_size_bytes > 100 * 1024 * 1024 * 1024 # More than 100 GB
        end

      {:error, %{message: "Error", result: error_message}} ->
        # This endpoint might require a Pro API key
        if String.contains?(error_message, "Pro") do
          assert true
        else
          flunk("Unexpected error: #{error_message}")
        end
    end
  end

  test "can fetch chain size data with all parameters" do
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      clienttype: "geth",
      syncmode: "default",
      sort: "asc",
      chainid: 1
    }])

    case result do
      {:ok, %{result: chain_size_data}} ->
        assert is_list(chain_size_data)
        assert true

      {:error, %{message: "Error", result: error_message}} ->
        # This endpoint might require a Pro API key
        if String.contains?(error_message, "Pro") do
          assert true
        else
          flunk("Unexpected error: #{error_message}")
        end
    end
  end

  test "can specify different sort order" do
    result = RateLimitedAPI.call_standard(ChainSize, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      sort: "desc",
      chainid: 1
    }])

    case result do
      {:ok, %{result: chain_size_data}} ->
        assert is_list(chain_size_data)
        assert true

      {:error, %{message: "Error", result: error_message}} ->
        # This endpoint might require a Pro API key
        if String.contains?(error_message, "Pro") do
          assert true
        else
          flunk("Unexpected error: #{error_message}")
        end
    end
  end
end

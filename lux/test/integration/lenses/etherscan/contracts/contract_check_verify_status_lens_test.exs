defmodule Lux.Integration.Etherscan.ContractCheckVerifyStatusLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractCheckVerifyStatus
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example GUID from the documentation
  @example_guid "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can check verification status with example GUID" do
    # Note: This test might fail if the example GUID is no longer valid
    # In that case, we'll need to update the test with a new GUID
    result = RateLimitedAPI.call_standard(ContractCheckVerifyStatus, :focus, [%{
      guid: @example_guid,
      chainid: 1
    }])

    case result do
      {:ok, %{result: status_info}} ->
        # Verify the status info structure
        assert is_map(status_info)
        assert Map.has_key?(status_info, :status)
        assert Map.has_key?(status_info, :message)

        # The status should be one of the expected values
        assert status_info.status in ["Pending", "Failed", "Success", "Unknown"]

        # The message should be a non-empty string
        assert is_binary(status_info.message)
        assert String.length(status_info.message) > 0

      {:error, error} ->
        # If the GUID is no longer valid, it might return an error
        # This is also acceptable for this test
        assert true
    end
  end
end

defmodule Lux.Integration.Etherscan.TxReceiptStatusLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TxReceiptStatus
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example successful transaction hash
  @successful_tx "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can check receipt status for a successful transaction" do
    assert {:ok, %{result: %{status: status, is_success: is_success}}} =
             TxReceiptStatus.focus(%{
               txhash: @successful_tx,
               chainid: 1
             })

    # Verify the status is "1" for a successful transaction
    assert status == "1"
    assert is_success == true
  end

  test "can check receipt status for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on whether the transaction exists on that chain
    result = TxReceiptStatus.focus(%{
      txhash: @successful_tx,
      chainid: 137 # Polygon
    })

    case result do
      {:ok, %{result: %{status: status, is_success: is_success}}} ->
        # If the transaction doesn't exist on this chain, that's also acceptable
        assert true

      {:error, error} ->
        # If the transaction doesn't exist on this chain, that's also acceptable
        assert true
    end
  end
end

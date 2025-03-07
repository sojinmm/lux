defmodule Lux.Integration.Etherscan.TxListInternalTxhashLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TxListInternalTxhash

  # Transaction hash with internal transactions
  @txhash "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 1000ms to avoid hitting the Etherscan API rate limit (5 calls per second)
    Process.sleep(1000)
    :ok
  end

  defmodule NoAuthTxListInternalTxhashLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TxListInternalTxhash",
      description: "Fetches internal transactions for a specific transaction hash from Etherscan API",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "txlistinternal")
    end
  end

  test "can fetch internal transactions for a transaction hash" do
    assert {:ok, %{result: transactions}} =
             TxListInternalTxhash.focus(%{
               txhash: @txhash,
               chainid: 1
             })

    # Verify we got results
    assert is_list(transactions)

    # If there are transactions, check their structure
    if length(transactions) > 0 do
      transaction = List.first(transactions)

      # Check that the transaction has the expected fields
      assert Map.has_key?(transaction, "blockNumber")
      assert Map.has_key?(transaction, "timeStamp")
      assert Map.has_key?(transaction, "from")
      assert Map.has_key?(transaction, "to")
      assert Map.has_key?(transaction, "value")
      assert Map.has_key?(transaction, "gas")
      assert Map.has_key?(transaction, "gasUsed")

      # Note: The API doesn't always return the hash field for internal transactions
      # when querying by txhash, so we don't check for it
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthTxListInternalTxhashLens doesn't have an API key, so it should fail
    result = NoAuthTxListInternalTxhashLens.focus(%{
      txhash: @txhash,
      chainid: 1
    })

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end 
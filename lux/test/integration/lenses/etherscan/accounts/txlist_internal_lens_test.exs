defmodule Lux.Integration.Etherscan.TxListInternalLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TxListInternal

  # Address with internal transactions (Uniswap V2 Router)
  @address "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
  # Transaction hash with internal transactions
  @txhash "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 1000ms to avoid hitting the Etherscan API rate limit (5 calls per second)
    Process.sleep(1000)
    :ok
  end

  defmodule NoAuthTxListInternalLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Internal Transaction List API",
      description: "Fetches internal transactions from Etherscan API",
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

  test "can fetch internal transactions for an address" do
    assert {:ok, %{result: transactions}} =
             TxListInternal.focus(%{
               address: @address,
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
      assert Map.has_key?(transaction, "hash")
      assert Map.has_key?(transaction, "from")
      assert Map.has_key?(transaction, "to")
      assert Map.has_key?(transaction, "value")
      assert Map.has_key?(transaction, "contractAddress")
      assert Map.has_key?(transaction, "input")
      assert Map.has_key?(transaction, "type")
      assert Map.has_key?(transaction, "gas")
      assert Map.has_key?(transaction, "gasUsed")
      assert Map.has_key?(transaction, "traceId")
      assert Map.has_key?(transaction, "isError")
      assert Map.has_key?(transaction, "errCode")

      # Verify the address is involved in the transaction (case-insensitive comparison)
      address_downcase = String.downcase(@address)
      from_address = if transaction["from"], do: String.downcase(transaction["from"]), else: nil
      to_address = if transaction["to"], do: String.downcase(transaction["to"]), else: nil

      assert from_address == address_downcase || to_address == address_downcase
    end
  end

  test "can fetch internal transactions for a transaction hash" do
    assert {:ok, %{result: transactions}} =
             TxListInternal.focus(%{
               txhash: @txhash,
               chainid: 1
             })

    # Verify we got results
    assert is_list(transactions)

    # If there are transactions, check their structure
    if length(transactions) > 0 do
      transaction = List.first(transactions)

      # Verify the transaction hash matches if the field exists
      if Map.has_key?(transaction, "hash") && transaction["hash"] do
        assert String.downcase(transaction["hash"]) == String.downcase(@txhash)
      end
    end
  end

  test "can fetch internal transactions by block range" do
    assert {:ok, %{result: transactions}} =
             TxListInternal.focus(%{
               startblock: 13481773,
               endblock: 13491773,
               chainid: 1
             })

    # Verify we got results
    assert is_list(transactions)

    # If there are transactions, check their structure
    if length(transactions) > 0 do
      transaction = List.first(transactions)

      # Verify the block number is within the specified range
      block_number = String.to_integer(transaction["blockNumber"])
      assert block_number >= 13481773
      assert block_number <= 13491773
    end
  end

  test "can fetch internal transactions with pagination" do
    assert {:ok, %{result: transactions}} =
             TxListInternal.focus(%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(transactions) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTxListInternalLens doesn't have an API key, so it should fail
    result = NoAuthTxListInternalLens.focus(%{
      address: @address,
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

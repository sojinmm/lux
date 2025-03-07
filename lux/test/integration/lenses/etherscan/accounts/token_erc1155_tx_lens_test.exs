defmodule Lux.Integration.Etherscan.TokenErc1155TxLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TokenErc1155Tx

  # Address with ERC-1155 token transfers
  @address "0x83f564d180b58ad9a02a449105568189ee7de8cb"
  # ERC-1155 contract address
  @contract_address "0x76be3b62873462d2142405439777e971754e8e77"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 1000ms to avoid hitting the Etherscan API rate limit (5 calls per second)
    Process.sleep(1000)
    :ok
  end

  defmodule NoAuthTokenErc1155TxLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ERC-1155 Token Transfer Events API",
      description: "Fetches ERC-1155 (Multi Token Standard) token transfer events from Etherscan API",
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
      |> Map.put(:action, "token1155tx")
    end
  end

  test "can fetch ERC-1155 transfers for an address" do
    assert {:ok, %{result: transfers}} =
             TokenErc1155Tx.focus(%{
               address: @address,
               chainid: 1
             })

    # Verify we got results
    assert is_list(transfers)

    # If there are transfers, check their structure
    if length(transfers) > 0 do
      transfer = List.first(transfers)

      # Check that the transfer has the expected fields
      assert Map.has_key?(transfer, "blockNumber")
      assert Map.has_key?(transfer, "timeStamp")
      assert Map.has_key?(transfer, "contractAddress")
      assert Map.has_key?(transfer, "from")
      assert Map.has_key?(transfer, "to")
      assert Map.has_key?(transfer, "tokenID")
      assert Map.has_key?(transfer, "tokenValue")

      # Verify the address is involved in the transfer
      address_downcase = String.downcase(@address)
      assert String.downcase(transfer["from"]) == address_downcase ||
             String.downcase(transfer["to"]) == address_downcase
    end
  end

  test "can fetch ERC-1155 transfers for a contract address" do
    assert {:ok, %{result: transfers}} =
             TokenErc1155Tx.focus(%{
               contractaddress: @contract_address,
               chainid: 1
             })

    # Verify we got results
    assert is_list(transfers)

    # If there are transfers, check their structure
    if length(transfers) > 0 do
      transfer = List.first(transfers)

      # Verify the contract address matches
      assert String.downcase(transfer["contractAddress"]) == String.downcase(@contract_address)
    end
  end

  test "can fetch ERC-1155 transfers for an address filtered by contract" do
    assert {:ok, %{result: transfers}} =
             TokenErc1155Tx.focus(%{
               address: @address,
               contractaddress: @contract_address,
               chainid: 1
             })

    # Verify we got results
    assert is_list(transfers)

    # If there are transfers, check their structure
    if length(transfers) > 0 do
      transfer = List.first(transfers)

      # Verify both the address and contract address match
      address_downcase = String.downcase(@address)
      assert String.downcase(transfer["from"]) == address_downcase ||
             String.downcase(transfer["to"]) == address_downcase
      assert String.downcase(transfer["contractAddress"]) == String.downcase(@contract_address)
    end
  end

  test "can fetch ERC-1155 transfers with pagination" do
    assert {:ok, %{result: transfers}} =
             TokenErc1155Tx.focus(%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenErc1155TxLens doesn't have an API key, so it should fail
    result = NoAuthTokenErc1155TxLens.focus(%{
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

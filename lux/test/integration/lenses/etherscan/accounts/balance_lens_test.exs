defmodule Lux.Integration.Etherscan.BalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.Balance

  # Vitalik's address
  @vitalik "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  # Ethereum Foundation address
  @eth_foundation "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 300ms to avoid hitting the Etherscan API rate limit (5 calls per second)
    Process.sleep(300)
    :ok
  end

  defmodule NoAuthBalanceLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Balance API",
      description: "Fetches ETH balance for an Ethereum address",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]
  end

  test "can fetch ETH balance for a single address" do
    assert {:ok, %{result: balance}} =
             Balance.focus(%{
               address: @vitalik,
               chainid: 1
             })

    # Convert balance from wei to ether for easier validation
    balance_in_eth = String.to_integer(balance) / 1.0e18

    # Vitalik should have some ETH (more than 0)
    assert is_binary(balance)
    assert balance_in_eth > 0

    # Log the balance for informational purposes
    IO.puts("Vitalik's balance: #{balance_in_eth} ETH")
  end

  test "can fetch ETH balance for a different address" do
    assert {:ok, %{result: balance}} =
             Balance.focus(%{
               address: @eth_foundation,
               chainid: 1
             })

    # Convert balance from wei to ether for easier validation
    balance_in_eth = String.to_integer(balance) / 1.0e18

    # Ethereum Foundation should have some ETH (more than 0)
    assert is_binary(balance)
    assert balance_in_eth > 0

    # Log the balance for informational purposes
    IO.puts("Ethereum Foundation's balance: #{balance_in_eth} ETH")
  end

  test "can specify a different tag (block parameter)" do
    assert {:ok, %{result: _balance}} =
             Balance.focus(%{
               address: @vitalik,
               chainid: 1,
               tag: "latest"
             })
  end

  test "returns zero balance for invalid address format" do
    # Etherscan API returns "0" for invalid addresses instead of an error
    assert {:ok, %{result: balance}} =
             Balance.focus(%{
               address: "0xinvalid",
               chainid: 1
             })

    assert balance == "0"
  end

  test "fails when no auth is provided" do
    # The NoAuthBalanceLens doesn't have an API key, so it should fail
    # but the response format is different than expected
    result = NoAuthBalanceLens.focus(%{
      address: @vitalik,
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

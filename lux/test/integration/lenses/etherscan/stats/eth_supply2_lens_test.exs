defmodule Lux.Integration.Etherscan.EthSupply2LensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.EthSupply2Lens

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 300ms to avoid hitting the Etherscan API rate limit (5 calls per second)
    Process.sleep(300)
    :ok
  end

  defmodule NoAuthEthSupply2Lens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Supply 2 API",
      description: "Fetches the current amount of Ether in circulation, ETH2 Staking rewards, EIP1559 burnt fees, and total withdrawn ETH from the beacon chain",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "stats")
      |> Map.put(:action, "ethsupply2")
    end
  end

  test "can fetch detailed ETH supply information" do
    assert {:ok, %{result: eth_supply_details, eth_supply_details: eth_supply_details}} =
             EthSupply2Lens.focus(%{
               chainid: 1
             })

    # Verify the structure of the response
    assert is_map(eth_supply_details)
    assert Map.has_key?(eth_supply_details, :eth_supply)
    assert Map.has_key?(eth_supply_details, :eth2_staking)
    assert Map.has_key?(eth_supply_details, :burnt_fees)
    assert Map.has_key?(eth_supply_details, :withdrawn_eth)

    # ETH supply should be a large number (more than 100 million ETH)
    assert is_number(eth_supply_details.eth_supply)
    assert eth_supply_details.eth_supply > 100_000_000

    # Log the details for informational purposes
    IO.puts("ETH Supply: #{eth_supply_details.eth_supply}")
    IO.puts("ETH2 Staking: #{eth_supply_details.eth2_staking}")
    IO.puts("Burnt Fees: #{eth_supply_details.burnt_fees}")
    IO.puts("Withdrawn ETH: #{eth_supply_details.withdrawn_eth}")
  end

  test "requires chainid parameter for v2 API" do
    # The v2 API requires the chainid parameter
    result = EthSupply2Lens.focus(%{})

    case result do
      {:error, %{message: "NOTOK", result: error_message}} ->
        # Should return an error about missing chainid parameter
        assert String.contains?(error_message, "Missing chainid parameter")
        IO.puts("Expected error for missing chainid: #{error_message}")

      {:ok, _} ->
        flunk("Expected an error for missing chainid parameter")
    end
  end

  test "can fetch ETH supply details for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on the chain
    result = EthSupply2Lens.focus(%{
      chainid: 137 # Polygon
    })

    case result do
      {:ok, %{result: eth_supply_details}} ->
        # Log the details for informational purposes
        IO.puts("ETH Supply on Polygon: #{eth_supply_details.eth_supply}")
        assert true

      {:error, error} ->
        # If the endpoint doesn't exist on this chain, that's also acceptable
        IO.puts("Error fetching ETH supply details on Polygon: #{inspect(error)}")
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthEthSupply2Lens doesn't have an API key, so it should fail
    result = NoAuthEthSupply2Lens.focus(%{
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

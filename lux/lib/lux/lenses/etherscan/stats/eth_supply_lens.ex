defmodule Lux.Lenses.Etherscan.EthSupplyLens do
  @moduledoc """
  Lens for fetching the current amount of Ether in circulation from the Etherscan API.
  This excludes ETH2 Staking rewards and EIP1559 burnt fees.

  ## Examples

  ```elixir
  # Get the current ETH supply (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.EthSupplyLens.focus(%{})

  # Get the current ETH supply for a specific chain
  Lux.Lenses.Etherscan.EthSupplyLens.focus(%{
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan ETH Supply API",
    description: "Fetches the current amount of Ether in circulation excluding ETH2 Staking rewards and EIP1559 burnt fees",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &BaseLens.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Chain ID to query (e.g., 1 for Ethereum)",
          default: 1
        }
      },
      required: []
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "ethsupply")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_binary(result) ->
        # Convert the result to a number if it's a string containing a number
        eth_supply =
          case Integer.parse(result) do
            {int_value, _} -> int_value
            :error -> result
          end

        # Return a structured response
        {:ok, %{
          result: eth_supply,
          eth_supply: eth_supply
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

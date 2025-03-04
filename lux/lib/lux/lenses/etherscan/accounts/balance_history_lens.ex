defmodule Lux.Lenses.Etherscan.BalanceHistoryLens do
  @moduledoc """
  Lens for fetching historical ETH balance for an Ethereum address at a specific block from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get historical ETH balance for an address at a specific block (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BalanceHistoryLens.focus(%{
    address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
    blockno: 8000000
  })

  # Get historical ETH balance for an address at a specific block on a specific chain
  Lux.Lenses.Etherscan.BalanceHistoryLens.focus(%{
    address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
    blockno: 8000000,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Historical ETH Balance API",
    description: "Fetches historical ETH balance for an Ethereum address at a specific block",
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
          description: "Chain ID to query (e.g., 1 for Ethereum, 137 for Polygon)",
          default: 1
        },
        address: %{
          type: :string,
          description: "Ethereum address to query",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        blockno: %{
          type: :integer,
          description: "Block number to check balance at"
        }
      },
      required: ["address", "blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  Validates that the required parameters are provided and checks if the endpoint requires a Pro API key.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "account")
    |> Map.put(:action, "balancehistory")

    # Check if this endpoint requires a Pro API key
    case BaseLens.check_pro_endpoint("account", "balancehistory") do
      {:ok, _} -> params
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    BaseLens.process_response(response)
  end
end

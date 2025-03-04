defmodule Lux.Lenses.Etherscan.BalanceLens do
  @moduledoc """
  Lens for fetching ETH balance for an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get ETH balance for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BalanceLens.focus(%{
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
  })

  # Get ETH balance for an address on a specific chain (e.g., 137 for Polygon)
  Lux.Lenses.Etherscan.BalanceLens.focus(%{
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    chainid: 137
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan ETH Balance API",
    description: "Fetches ETH balance for an Ethereum address",
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
        tag: %{
          type: :string,
          description: "Block parameter",
          enum: ["latest", "pending", "earliest"],
          default: "latest"
        }
      },
      required: ["address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "balance")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    BaseLens.process_response(response)
  end
end

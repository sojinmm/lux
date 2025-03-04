defmodule Lux.Lenses.Etherscan.TokenBalanceHistoryLens do
  @moduledoc """
  Lens for fetching the balance of an ERC-20 token of an address at a certain block height from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get historical ERC20 token balance for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TokenBalanceHistoryLens.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
    blockno: 8000000
  })

  # Get historical ERC20 token balance for an address on a specific chain
  Lux.Lenses.Etherscan.TokenBalanceHistoryLens.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
    blockno: 8000000,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Historical ERC20 Token Balance API",
    description: "Fetches the balance of an ERC-20 token of an address at a certain block height",
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
        },
        contractaddress: %{
          type: :string,
          description: "The contract address of the ERC-20 token",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        address: %{
          type: :string,
          description: "The address to check for token balance",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        blockno: %{
          type: :integer,
          description: "The integer block number to check balance for"
        }
      },
      required: ["contractaddress", "address", "blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "tokenbalancehistory")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} ->
        # Return a structured response with the historical token balance
        {:ok, %{
          result: result,
          token_balance: result,
          block_number: Map.get(response, "blockNumber", nil)
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

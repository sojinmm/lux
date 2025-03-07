defmodule Lux.Lenses.Etherscan.TokenErc1155Tx do
  @moduledoc """
  Lens for fetching ERC-1155 (Multi Token Standard) token transfer events from the Etherscan API.

  This lens supports three different query types:
  1. ERC-1155 transfers from an address - specify the address parameter
  2. ERC-1155 transfers from a contract address - specify the contract address parameter
  3. ERC-1155 transfers from an address filtered by a token contract - specify both address and contract address parameters

  ## Examples

  ```elixir
  # Get ERC-1155 transfers for an address
  Lux.Lenses.Etherscan.TokenErc1155Tx.focus(%{
    address: "0x83f564d180b58ad9a02a449105568189ee7de8cb"
  })

  # Get ERC-1155 transfers for a token contract
  Lux.Lenses.Etherscan.TokenErc1155Tx.focus(%{
    contractaddress: "0x76be3b62873462d2142405439777e971754e8e77"
  })

  # Get ERC-1155 transfers for an address filtered by a token contract
  Lux.Lenses.Etherscan.TokenErc1155Tx.focus(%{
    address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
    contractaddress: "0x76be3b62873462d2142405439777e971754e8e77"
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TokenErc1155Tx.focus(%{
    address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
    contractaddress: "0x76be3b62873462d2142405439777e971754e8e77",
    chainid: 1,
    startblock: 0,
    endblock: 27025780,
    page: 1,
    offset: 100,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan ERC-1155 Token Transfer Events API",
    description: "Fetches ERC-1155 (Multi Token Standard) token transfer events from Etherscan API",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
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
          description: "Ethereum address to query for ERC-1155 transfers",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        contractaddress: %{
          type: :string,
          description: "ERC-1155 contract address to filter transfers",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Starting block number",
          default: 0
        },
        endblock: %{
          type: :integer,
          description: "Ending block number",
          default: 99999999
        },
        page: %{
          type: :integer,
          description: "Page number for pagination",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of transactions per page",
          default: 100
        },
        sort: %{
          type: :string,
          description: "Sorting direction",
          enum: ["asc", "desc"],
          default: "asc"
        }
      },
      oneOf: [
        %{required: ["address"]},
        %{required: ["contractaddress"]},
        %{required: ["address", "contractaddress"]}
      ]
    }

  @doc """
  Prepares parameters before making the API request.
  Validates that at least one of the required parameters is provided.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "account")
    |> Map.put(:action, "token1155tx")

    # Validate that at least one of the required parameters is provided
    cond do
      Map.has_key?(params, :address) || Map.has_key?(params, :contractaddress) ->
        # Valid parameters
        params

      true ->
        # Invalid parameters
        raise ArgumentError, "Invalid query parameters. Must include either 'address', 'contractaddress', or both."
    end
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end

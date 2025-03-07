defmodule Lux.Lenses.Etherscan.TokenNftTx do
  @moduledoc """
  Lens for fetching ERC-721 (NFT) token transfer events from the Etherscan API.

  This lens supports three different query types:
  1. ERC-721 transfers from an address - specify the address parameter
  2. ERC-721 transfers from a contract address - specify the contract address parameter
  3. ERC-721 transfers from an address filtered by a token contract - specify both address and contract address parameters

  ## Examples

  ```elixir
  # Get ERC-721 transfers for an address
  Lux.Lenses.Etherscan.TokenNftTx.focus(%{
    address: "0x6975be450864c02b4613023c2152ee0743572325"
  })

  # Get ERC-721 transfers for a token contract
  Lux.Lenses.Etherscan.TokenNftTx.focus(%{
    contractaddress: "0x06012c8cf97bead5deae237070f9587f8e7a266d"
  })

  # Get ERC-721 transfers for an address filtered by a token contract
  Lux.Lenses.Etherscan.TokenNftTx.focus(%{
    address: "0x6975be450864c02b4613023c2152ee0743572325",
    contractaddress: "0x06012c8cf97bead5deae237070f9587f8e7a266d"
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TokenNftTx.focus(%{
    address: "0x6975be450864c02b4613023c2152ee0743572325",
    contractaddress: "0x06012c8cf97bead5deae237070f9587f8e7a266d",
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
    name: "Etherscan ERC-721 NFT Token Transfer Events API",
    description: "Fetches ERC-721 (NFT) token transfer events from Etherscan API",
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
          description: "Ethereum address to query for NFT transfers",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        contractaddress: %{
          type: :string,
          description: "NFT contract address to filter transfers",
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
    |> Map.put(:action, "tokennfttx")

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

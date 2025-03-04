defmodule Lux.Lenses.Etherscan.TokenTxLens do
  @moduledoc """
  Lens for fetching ERC-20 token transfer events from the Etherscan API.

  This lens supports three different query types:
  1. ERC-20 transfers from an address - specify the address parameter
  2. ERC-20 transfers from a contract address - specify the contract address parameter
  3. ERC-20 transfers from an address filtered by a token contract - specify both address and contract address parameters

  ## Examples

  ```elixir
  # Get ERC-20 transfers for an address
  Lux.Lenses.Etherscan.TokenTxLens.focus(%{
    address: "0x4e83362442b8d1bec281594cea3050c8eb01311c"
  })

  # Get ERC-20 transfers for a token contract
  Lux.Lenses.Etherscan.TokenTxLens.focus(%{
    contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"
  })

  # Get ERC-20 transfers for an address filtered by a token contract
  Lux.Lenses.Etherscan.TokenTxLens.focus(%{
    address: "0x4e83362442b8d1bec281594cea3050c8eb01311c",
    contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TokenTxLens.focus(%{
    address: "0x4e83362442b8d1bec281594cea3050c8eb01311c",
    contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    chainid: 1,
    startblock: 0,
    endblock: 27025780,
    page: 1,
    offset: 100,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan ERC-20 Token Transfer Events API",
    description: "Fetches ERC-20 token transfer events from Etherscan API",
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
          description: "Ethereum address to query for token transfers",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        contractaddress: %{
          type: :string,
          description: "Token contract address to filter transfers",
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
    |> Map.put(:action, "tokentx")

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
    BaseLens.process_response(response)
  end
end

defmodule Lux.Lenses.Etherscan.MinedBlocksLens do
  @moduledoc """
  Lens for fetching blocks validated (mined) by an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get blocks validated by an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.MinedBlocksLens.focus(%{
    address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b"
  })

  # Get blocks validated by an address with pagination
  Lux.Lenses.Etherscan.MinedBlocksLens.focus(%{
    address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
    blocktype: "blocks",
    page: 1,
    offset: 10
  })

  # Get uncle blocks validated by an address
  Lux.Lenses.Etherscan.MinedBlocksLens.focus(%{
    address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
    blocktype: "uncles"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Mined Blocks API",
    description: "Fetches blocks validated by an Ethereum address",
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
          description: "Ethereum address to query for validated blocks",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        blocktype: %{
          type: :string,
          description: "Type of blocks to return",
          enum: ["blocks", "uncles"],
          default: "blocks"
        },
        page: %{
          type: :integer,
          description: "Page number for pagination",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of blocks per page",
          default: 10
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
    |> Map.put(:action, "getminedblocks")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    BaseLens.process_response(response)
  end
end

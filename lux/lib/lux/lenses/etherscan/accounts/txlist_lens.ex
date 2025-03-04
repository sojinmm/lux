defmodule Lux.Lenses.Etherscan.TxListLens do
  @moduledoc """
  Lens for fetching normal transactions for an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get transactions for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TxListLens.focus(%{
    address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
  })

  # Get transactions with pagination and block range
  Lux.Lenses.Etherscan.TxListLens.focus(%{
    address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
    chainid: 1,
    startblock: 0,
    endblock: 99999999,
    page: 1,
    offset: 10,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Transaction List API",
    description: "Fetches normal transactions for an Ethereum address",
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
          default: 10
        },
        sort: %{
          type: :string,
          description: "Sorting direction",
          enum: ["asc", "desc"],
          default: "asc"
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
    |> Map.put(:action, "txlist")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    BaseLens.process_response(response)
  end
end

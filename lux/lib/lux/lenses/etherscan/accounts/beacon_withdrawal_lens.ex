defmodule Lux.Lenses.Etherscan.BeaconWithdrawalLens do
  @moduledoc """
  Lens for fetching beacon chain withdrawals made to an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get beacon chain withdrawals for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BeaconWithdrawalLens.focus(%{
    address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f"
  })

  # Get beacon chain withdrawals for an address with pagination and block range
  Lux.Lenses.Etherscan.BeaconWithdrawalLens.focus(%{
    address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
    startblock: 17000000,
    endblock: 18000000,
    page: 1,
    offset: 10,
    sort: "desc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Beacon Chain Withdrawals API",
    description: "Fetches beacon chain withdrawals made to an Ethereum address",
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
          description: "Ethereum address to query for beacon withdrawals",
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
          description: "Number of withdrawals per page",
          default: 100
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
    |> Map.put(:action, "txsBeaconWithdrawal")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    BaseLens.process_response(response)
  end
end

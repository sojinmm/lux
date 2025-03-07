defmodule Lux.Lenses.Etherscan.TxListInternal do
  @moduledoc """
  Lens for fetching internal transactions from the Etherscan API.

  This lens supports three different query types:
  1. By Address - Get internal transactions for a specific Ethereum address
  2. By Transaction Hash - Get internal transactions within a specific transaction
  3. By Block Range - Get internal transactions within a specific block range

  ## Examples

  ```elixir
  # Get internal transactions by address
  Lux.Lenses.Etherscan.TxListInternal.focus(%{
    address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3"
  })

  # Get internal transactions by transaction hash
  Lux.Lenses.Etherscan.TxListInternal.focus(%{
    txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
  })

  # Get internal transactions by block range
  Lux.Lenses.Etherscan.TxListInternal.focus(%{
    startblock: 13481773,
    endblock: 13491773
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TxListInternal.focus(%{
    address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
    chainid: 1,
    startblock: 0,
    endblock: 2702578,
    page: 1,
    offset: 10,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan Internal Transaction List API",
    description: "Fetches internal transactions from Etherscan API",
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
          description: "Ethereum address to query for internal transactions",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        txhash: %{
          type: :string,
          description: "Transaction hash to query for internal transactions",
          pattern: "^0x[a-fA-F0-9]{64}$"
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
      oneOf: [
        %{required: ["address"]},
        %{required: ["txhash"]},
        %{required: ["startblock", "endblock"]}
      ]
    }

  @doc """
  Prepares parameters before making the API request.
  Validates that one of the three query types is used.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "account")
    |> Map.put(:action, "txlistinternal")

    # Validate that one of the three query types is used
    cond do
      Map.has_key?(params, :address) ->
        # Query by address
        params

      Map.has_key?(params, :txhash) ->
        # Query by transaction hash
        params

      Map.has_key?(params, :startblock) && Map.has_key?(params, :endblock) ->
        # Query by block range
        params

      true ->
        # Invalid query type
        raise ArgumentError, "Invalid query parameters. Must include either 'address', 'txhash', or both 'startblock' and 'endblock'."
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

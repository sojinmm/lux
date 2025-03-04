defmodule Lux.Lenses.Etherscan.TokenHolderListLens do
  @moduledoc """
  Lens for fetching the current ERC20 token holders and number of tokens held from the Etherscan API.

  ## Examples

  ```elixir
  # Get token holder list (default chainid: 1 for Ethereum, page: 1, offset: 10)
  Lux.Lenses.Etherscan.TokenHolderListLens.focus(%{
    contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"
  })

  # Get token holder list with pagination
  Lux.Lenses.Etherscan.TokenHolderListLens.focus(%{
    contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
    page: 1,
    offset: 10,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Token Holder List API",
    description: "Fetches the current ERC20 token holders and number of tokens held",
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
        page: %{
          type: :integer,
          description: "The integer page number, if pagination is enabled",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "The number of token holders displayed per page",
          default: 10
        }
      },
      required: ["contractaddress"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Ensure page and offset parameters have default values
    params = params
    |> Map.put_new(:page, 1)
    |> Map.put_new(:offset, 10)

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "token")
    |> Map.put(:action, "tokenholderlist")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        # Process the list of token holders
        processed_results = Enum.map(result, fn holder ->
          %{
            address: Map.get(holder, "TokenHolderAddress", ""),
            quantity: Map.get(holder, "TokenHolderQuantity", ""),
            share: Map.get(holder, "TokenHolderShare", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          token_holders: processed_results
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

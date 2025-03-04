defmodule Lux.Lenses.Etherscan.TokenBalanceLens do
  @moduledoc """
  Lens for fetching the current balance of an ERC-20 token of an address from the Etherscan API.

  ## Examples

  ```elixir
  # Get ERC20 token balance for an address (default chainid: 1 for Ethereum, tag: "latest")
  Lux.Lenses.Etherscan.TokenBalanceLens.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761"
  })

  # Get ERC20 token balance for an address on a specific chain
  Lux.Lenses.Etherscan.TokenBalanceLens.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
    tag: "latest",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan ERC20 Token Balance API",
    description: "Fetches the current balance of an ERC-20 token of an address",
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
        tag: %{
          type: :string,
          description: "Block parameter",
          enum: ["latest", "pending", "earliest"],
          default: "latest"
        }
      },
      required: ["contractaddress", "address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Ensure tag parameter has a default value
    params = case params[:tag] do
      nil -> Map.put(params, :tag, "latest")
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "tokenbalance")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} ->
        # Return a structured response with the token balance
        {:ok, %{
          result: result,
          token_balance: result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

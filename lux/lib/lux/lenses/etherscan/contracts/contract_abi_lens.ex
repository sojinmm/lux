defmodule Lux.Lenses.Etherscan.ContractAbiLens do
  @moduledoc """
  Lens for fetching the Contract Application Binary Interface (ABI) of a verified smart contract from the Etherscan API.

  ## Examples

  ```elixir
  # Get contract ABI for a verified contract (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.ContractAbiLens.focus(%{
    address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
  })

  # Get contract ABI for a verified contract on a specific chain
  Lux.Lenses.Etherscan.ContractAbiLens.focus(%{
    address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Contract ABI API",
    description: "Fetches the ABI of a verified smart contract",
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
          description: "Contract address with verified source code",
          pattern: "^0x[a-fA-F0-9]{40}$"
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
    |> Map.put(:module, "contract")
    |> Map.put(:action, "getabi")
  end

  @doc """
  Transforms the API response into a more usable format.
  For contract ABI, we need to parse the JSON string in the result.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_binary(result) ->
        # Try to parse the ABI JSON string
        case Jason.decode(result) do
          {:ok, parsed_abi} ->
            {:ok, %{result: parsed_abi}}
          {:error, _} ->
            # If parsing fails, return the original string
            {:ok, %{result: result}}
        end
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

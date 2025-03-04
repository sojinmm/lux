defmodule Lux.Lenses.Etherscan.NodeCountLens do
  @moduledoc """
  Lens for fetching the total number of discoverable Ethereum nodes from the Etherscan API.

  ## Examples

  ```elixir
  # Get the total number of Ethereum nodes (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.NodeCountLens.focus(%{})

  # Get the total number of Ethereum nodes for a specific chain
  Lux.Lenses.Etherscan.NodeCountLens.focus(%{
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Node Count API",
    description: "Fetches the total number of discoverable Ethereum nodes",
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
        }
      },
      required: []
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "nodecount")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Process the result map and convert string values to integers
        processed_result = %{
          total: parse_integer_or_keep(Map.get(result, "TotalNodeCount", "")),
          eth_nodes: parse_integer_or_keep(Map.get(result, "EthNodeCount", "")),
          geth_nodes: parse_integer_or_keep(Map.get(result, "GethNodeCount", "")),
          parity_nodes: parse_integer_or_keep(Map.get(result, "ParityNodeCount", "")),
          other_nodes: parse_integer_or_keep(Map.get(result, "OtherNodeCount", ""))
        }

        # Return a structured response
        {:ok, %{
          result: processed_result,
          node_count: processed_result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end

  # Helper function to parse string to integer or keep as is
  defp parse_integer_or_keep(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> value
    end
  end
  defp parse_integer_or_keep(value), do: value
end

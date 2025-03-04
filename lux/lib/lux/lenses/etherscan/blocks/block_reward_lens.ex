defmodule Lux.Lenses.Etherscan.BlockRewardLens do
  @moduledoc """
  Lens for fetching block and uncle rewards for a specific block from the Etherscan API.

  ## Examples

  ```elixir
  # Get block rewards for a specific block (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BlockRewardLens.focus(%{
    blockno: 2165403
  })

  # Get block rewards for a specific block on a specific chain
  Lux.Lenses.Etherscan.BlockRewardLens.focus(%{
    blockno: 2165403,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Block Reward API",
    description: "Fetches block and uncle rewards for a specific block",
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
        blockno: %{
          type: [:integer, :string],
          description: "Block number to check rewards for"
        }
      },
      required: ["blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Convert blockno to string if it's an integer
    params = case params[:blockno] do
      blockno when is_integer(blockno) -> Map.put(params, :blockno, to_string(blockno))
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "block")
    |> Map.put(:action, "getblockreward")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Extract the relevant information
        block_number = Map.get(result, "blockNumber")
        timestamp = Map.get(result, "timeStamp")
        block_miner = Map.get(result, "blockMiner")
        block_reward = Map.get(result, "blockReward")
        uncles = Map.get(result, "uncles", [])

        # Process uncles to a more structured format
        processed_uncles = Enum.map(uncles, fn uncle ->
          %{
            miner: Map.get(uncle, "miner"),
            uncle_position: Map.get(uncle, "unclePosition"),
            block_reward: Map.get(uncle, "blockreward")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: %{
            block_number: block_number,
            timestamp: timestamp,
            block_miner: block_miner,
            block_reward: block_reward,
            uncles: processed_uncles
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

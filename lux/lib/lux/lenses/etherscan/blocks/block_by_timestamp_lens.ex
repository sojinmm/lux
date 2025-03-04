defmodule Lux.Lenses.Etherscan.BlockByTimestampLens do
  @moduledoc """
  Lens for fetching the block number that was mined at a certain timestamp from the Etherscan API.

  ## Examples

  ```elixir
  # Get block number by timestamp (default chainid: 1 for Ethereum, closest: "before")
  Lux.Lenses.Etherscan.BlockByTimestampLens.focus(%{
    timestamp: 1578638524
  })

  # Get block number by timestamp with specific parameters
  Lux.Lenses.Etherscan.BlockByTimestampLens.focus(%{
    timestamp: 1578638524,
    closest: "after",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Block Number by Timestamp API",
    description: "Fetches the block number that was mined at a certain timestamp",
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
        timestamp: %{
          type: [:integer, :string],
          description: "The Unix timestamp in seconds"
        },
        closest: %{
          type: :string,
          description: "The closest available block to the provided timestamp, either 'before' or 'after'",
          enum: ["before", "after"],
          default: "before"
        }
      },
      required: ["timestamp"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Convert timestamp to string if it's an integer
    params = case params[:timestamp] do
      timestamp when is_integer(timestamp) -> Map.put(params, :timestamp, to_string(timestamp))
      _ -> params
    end

    # Ensure closest parameter has a default value
    params = case params[:closest] do
      nil -> Map.put(params, :closest, "before")
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "block")
    |> Map.put(:action, "getblocknobytime")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_binary(result) ->
        # Return a structured response with the block number
        {:ok, %{
          result: %{
            block_number: result
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

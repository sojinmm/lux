defmodule Lux.Lenses.Etherscan.DailyBlockCountLens do
  @moduledoc """
  Lens for fetching the number of blocks mined daily and the amount of block rewards within a date range from the Etherscan API.

  Note: This endpoint requires an Etherscan Pro API key.

  ## Examples

  ```elixir
  # Get daily block count and rewards for a date range (default chainid: 1 for Ethereum, sort: "asc")
  Lux.Lenses.Etherscan.DailyBlockCountLens.focus(%{
    startdate: "2019-02-01",
    enddate: "2019-02-28"
  })

  # Get daily block count and rewards for a date range with specific parameters
  Lux.Lenses.Etherscan.DailyBlockCountLens.focus(%{
    startdate: "2019-02-01",
    enddate: "2019-02-28",
    sort: "desc",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    name: "Etherscan Daily Block Count and Rewards API",
    description: "Fetches the number of blocks mined daily and the amount of block rewards",
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
        startdate: %{
          type: :string,
          description: "The starting date in yyyy-MM-dd format, e.g., 2019-02-01"
        },
        enddate: %{
          type: :string,
          description: "The ending date in yyyy-MM-dd format, e.g., 2019-02-28"
        },
        sort: %{
          type: :string,
          description: "The sorting preference, use 'asc' to sort by ascending and 'desc' to sort by descending",
          enum: ["asc", "desc"],
          default: "asc"
        }
      },
      required: ["startdate", "enddate"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Ensure sort parameter has a default value
    params = case params[:sort] do
      nil -> Map.put(params, :sort, "asc")
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailyblkcount")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        # Process the list of daily block counts and rewards
        processed_results = Enum.map(result, fn item ->
          %{
            date: Map.get(item, "UTCDate", ""),
            block_count: Map.get(item, "blockCount", ""),
            block_rewards: Map.get(item, "blockRewards", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results
        }}
      {:error, %{result: "Invalid API Key"}} ->
        # Handle Pro API key error
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

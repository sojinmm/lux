defmodule Lux.Lenses.Etherscan.DailyAvgNetDifficultyLens do
  @moduledoc """
  Lens for fetching the historical mining difficulty of the Ethereum network from the Etherscan API.

  ## Examples

  Fetch daily average network difficulty for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyAvgNetDifficultyLens.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", difficulty: 12345678901234.56},
          %{utc_date: "2023-01-02", difficulty: 12345678901235.67},
          %{utc_date: "2023-01-03", difficulty: 12345678901236.78}
        ],
        daily_avg_net_difficulty: [
          %{utc_date: "2023-01-01", difficulty: 12345678901234.56},
          %{utc_date: "2023-01-02", difficulty: 12345678901235.67},
          %{utc_date: "2023-01-03", difficulty: 12345678901236.78}
        ]
      }}

  Fetch daily average network difficulty for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyAvgNetDifficultyLens.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", difficulty: 12345678901238.90},
          %{utc_date: "2023-01-04", difficulty: 12345678901237.89},
          %{utc_date: "2023-01-03", difficulty: 12345678901236.78}
        ],
        daily_avg_net_difficulty: [
          %{utc_date: "2023-01-05", difficulty: 12345678901238.90},
          %{utc_date: "2023-01-04", difficulty: 12345678901237.89},
          %{utc_date: "2023-01-03", difficulty: 12345678901236.78}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.BaseLens

  use Lux.Lens,
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &BaseLens.add_api_key/1
    },
    schema: [
      chainid: [type: :integer, required: true],
      startdate: [type: :string, required: true],
      enddate: [type: :string, required: true],
      sort: [type: :string, required: false]
    ]

  @doc """
  Prepares parameters for the API request.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "stats")
    |> Map.put(:action, "dailyavgnetdifficulty")
    |> Map.put_new(:sort, "asc")
  end

  @doc """
  Processes the API response.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        difficulty_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              difficulty: parse_float_or_keep(item["networkDifficulty"])
            }
          end)

        {:ok, %{result: difficulty_data, daily_avg_net_difficulty: difficulty_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_avg_net_difficulty: []}}

      {:error, %{result: "This endpoint requires a Pro subscription"}} ->
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}

      other ->
        other
    end
  end

  defp parse_float_or_keep(value) when is_binary(value) do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> value
    end
  end

  defp parse_float_or_keep(value), do: value
end

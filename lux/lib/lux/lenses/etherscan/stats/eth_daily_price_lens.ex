defmodule Lux.Lenses.Etherscan.EthDailyPriceLens do
  @moduledoc """
  Lens for fetching the historical price of 1 ETH from the Etherscan API.

  ## Examples

  Fetch Ether historical price for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.EthDailyPriceLens.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", eth_usd: 1234.56, eth_btc: 0.07654},
          %{utc_date: "2023-01-02", eth_usd: 1345.67, eth_btc: 0.07765},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07876}
        ],
        eth_daily_price: [
          %{utc_date: "2023-01-01", eth_usd: 1234.56, eth_btc: 0.07654},
          %{utc_date: "2023-01-02", eth_usd: 1345.67, eth_btc: 0.07765},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07876}
        ]
      }}

  Fetch Ether historical price for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.EthDailyPriceLens.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", eth_usd: 1678.90, eth_btc: 0.08098},
          %{utc_date: "2023-01-04", eth_usd: 1567.89, eth_btc: 0.07987},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07876}
        ],
        eth_daily_price: [
          %{utc_date: "2023-01-05", eth_usd: 1678.90, eth_btc: 0.08098},
          %{utc_date: "2023-01-04", eth_usd: 1567.89, eth_btc: 0.07987},
          %{utc_date: "2023-01-03", eth_usd: 1456.78, eth_btc: 0.07876}
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
    |> Map.put(:action, "ethdailyprice")
    |> Map.put_new(:sort, "asc")
  end

  @doc """
  Processes the API response.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        price_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              eth_usd: parse_float_or_keep(item["value"]),
              eth_btc: parse_float_or_keep(item["ethBtc"])
            }
          end)

        {:ok, %{result: price_data, eth_daily_price: price_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], eth_daily_price: []}}

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

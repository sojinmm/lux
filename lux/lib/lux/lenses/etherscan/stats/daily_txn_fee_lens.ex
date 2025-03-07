defmodule Lux.Lenses.Etherscan.DailyTxnFee do
  @moduledoc """
  Lens for fetching the amount of transaction fees paid to miners per day from the Etherscan API.

  ## Examples

  Fetch daily transaction fees for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyTxnFee.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", tx_fee_eth: 123.45},
          %{utc_date: "2023-01-02", tx_fee_eth: 234.56},
          %{utc_date: "2023-01-03", tx_fee_eth: 345.67}
        ],
        daily_txn_fee: [
          %{utc_date: "2023-01-01", tx_fee_eth: 123.45},
          %{utc_date: "2023-01-02", tx_fee_eth: 234.56},
          %{utc_date: "2023-01-03", tx_fee_eth: 345.67}
        ]
      }}

  Fetch daily transaction fees for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyTxnFee.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", tx_fee_eth: 567.89},
          %{utc_date: "2023-01-04", tx_fee_eth: 456.78},
          %{utc_date: "2023-01-03", tx_fee_eth: 345.67}
        ],
        daily_txn_fee: [
          %{utc_date: "2023-01-05", tx_fee_eth: 567.89},
          %{utc_date: "2023-01-04", tx_fee_eth: 456.78},
          %{utc_date: "2023-01-03", tx_fee_eth: 345.67}
        ]
      }}
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
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
    |> Map.put(:action, "dailytxnfee")
    |> Map.put_new(:sort, "asc")
  end

  @doc """
  Processes the API response.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        txn_fee_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              tx_fee_eth: parse_float_or_keep(item["transactionFee_Eth"])
            }
          end)

        {:ok, %{result: txn_fee_data, daily_txn_fee: txn_fee_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_txn_fee: []}}

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

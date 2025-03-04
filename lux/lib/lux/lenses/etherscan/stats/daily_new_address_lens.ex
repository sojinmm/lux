defmodule Lux.Lenses.Etherscan.DailyNewAddressLens do
  @moduledoc """
  Lens for fetching the number of new Ethereum addresses created per day from the Etherscan API.

  ## Examples

  Fetch daily new address counts for a specific date range in ascending order:

      iex> Lux.Lenses.Etherscan.DailyNewAddressLens.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "asc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-01", new_address_count: 12345},
          %{utc_date: "2023-01-02", new_address_count: 23456},
          %{utc_date: "2023-01-03", new_address_count: 34567}
        ],
        daily_new_address: [
          %{utc_date: "2023-01-01", new_address_count: 12345},
          %{utc_date: "2023-01-02", new_address_count: 23456},
          %{utc_date: "2023-01-03", new_address_count: 34567}
        ]
      }}

  Fetch daily new address counts for a specific date range in descending order:

      iex> Lux.Lenses.Etherscan.DailyNewAddressLens.focus(%{
      ...>   startdate: "2023-01-01",
      ...>   enddate: "2023-01-05",
      ...>   sort: "desc",
      ...>   chainid: 1
      ...> })
      {:ok, %{
        result: [
          %{utc_date: "2023-01-05", new_address_count: 56789},
          %{utc_date: "2023-01-04", new_address_count: 45678},
          %{utc_date: "2023-01-03", new_address_count: 34567}
        ],
        daily_new_address: [
          %{utc_date: "2023-01-05", new_address_count: 56789},
          %{utc_date: "2023-01-04", new_address_count: 45678},
          %{utc_date: "2023-01-03", new_address_count: 34567}
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
    |> Map.put(:action, "dailynewaddress")
    |> Map.put_new(:sort, "asc")
  end

  @doc """
  Processes the API response.
  """
  @impl true
  def after_focus(response) do
    case BaseLens.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        new_address_data =
          Enum.map(result, fn item ->
            %{
              utc_date: item["UTCDate"],
              new_address_count: parse_integer_or_keep(item["newAddressCount"])
            }
          end)

        {:ok, %{result: new_address_data, daily_new_address: new_address_data}}

      {:error, %{result: "No data found"}} ->
        {:ok, %{result: [], daily_new_address: []}}

      {:error, %{result: "This endpoint requires a Pro subscription"}} ->
        {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}

      other ->
        other
    end
  end

  defp parse_integer_or_keep(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> value
    end
  end

  defp parse_integer_or_keep(value), do: value
end

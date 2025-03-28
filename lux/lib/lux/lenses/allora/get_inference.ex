defmodule Lux.Lenses.Allora.GetInference do
  @moduledoc """
  A lens for fetching inference data for a specific topic from the Allora API.
  This lens supports both topic ID-based inference and price inference for specific assets.

  ## Examples
      iex> GetInference.focus(%{
      ...>   topic_id: 1,
      ...>   signature_format: "ethereum-11155111"
      ...> })
      {:ok, %{
        signature: "0x...",
        inference_data: %{
          network_inference: "1234567890",
          network_inference_normalized: "0.12345",
          confidence_interval_percentiles: ["0.1", "0.5", "0.9"],
          confidence_interval_percentiles_normalized: ["0.1", "0.5", "0.9"],
          confidence_interval_values: ["1200000000", "1234567890", "1300000000"],
          confidence_interval_values_normalized: ["0.12", "0.12345", "0.13"],
          topic_id: "1",
          timestamp: 1679529600,
          extra_data: ""
        }
      }}

      # Price inference for specific asset
      iex> GetInference.focus(%{
      ...>   asset: "BTC",
      ...>   timeframe: "5m",
      ...>   signature_format: "ethereum-11155111"
      ...> })
      {:ok, %{...}}
  """

  alias Lux.Integrations.Allora
  require Logger

  use Lux.Lens,
    name: "Get Allora Inference",
    description: "Fetches inference data from the Allora network",
    url: "#{Allora.base_url()}/allora/consumer/:signature_format",
    method: :get,
    headers: Allora.headers(),
    auth: Allora.auth(),
    schema: %{
      type: :object,
      properties: %{
        topic_id: %{
          type: :integer,
          description: "The unique identifier of the topic to get inference for"
        },
        asset: %{
          type: :string,
          description: "The asset to get price inference for (e.g. 'BTC', 'ETH')",
          enum: ["BTC", "ETH"]
        },
        timeframe: %{
          type: :string,
          description: "The timeframe for price inference",
          enum: ["5m", "8h"]
        },
        signature_format: %{
          type: :string,
          description: "The signature format to use",
          default: "ethereum-11155111"
        }
      },
      oneOf: [
        %{required: ["topic_id"]},
        %{required: ["asset", "timeframe"]}
      ]
    }

  @impl true
  def before_focus(%{topic_id: topic_id} = params) do
    signature_format = Map.get(params, :signature_format, "ethereum-11155111")
    url = "#{Allora.base_url()}/allora/consumer/#{signature_format}?allora_topic_id=#{topic_id}&inference_value_type=uint256"

    Logger.debug("Allora GetInference before_focus (topic): #{inspect(%{url: url, params: params})}")

    %{url: url}
  end

  def before_focus(%{asset: asset, timeframe: timeframe} = params) do
    signature_format = Map.get(params, :signature_format, "ethereum-11155111")
    url = "#{Allora.base_url()}/allora/consumer/price/#{signature_format}/#{asset}/#{timeframe}"

    Logger.debug("Allora GetInference before_focus (price): #{inspect(%{url: url, params: params})}")

    %{url: url}
  end

  @doc """
  Transforms the Allora API response into a simpler format.

  ## Examples
      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "signature" => "0x...",
      ...>     "inference_data" => %{
      ...>       "network_inference" => "1234567890"
      ...>     }
      ...>   }
      ...> })
      {:ok, %{signature: "0x...", inference_data: %{network_inference: "1234567890"}}}
  """
  @impl true
  def after_focus(%{"data" => %{"signature" => signature, "inference_data" => inference_data}} = response) do
    Logger.debug("Allora GetInference after_focus success: #{inspect(response)}")

    Logger.info("Successfully fetched inference data from Allora API (chain_id: #{Allora.chain_id()}, topic_id: #{inference_data["topic_id"]}, timestamp: #{inference_data["timestamp"]})")

    {:ok, %{
      signature: signature,
      inference_data: %{
        network_inference: inference_data["network_inference"],
        network_inference_normalized: inference_data["network_inference_normalized"],
        confidence_interval_percentiles: inference_data["confidence_interval_percentiles"],
        confidence_interval_percentiles_normalized: inference_data["confidence_interval_percentiles_normalized"],
        confidence_interval_values: inference_data["confidence_interval_values"],
        confidence_interval_values_normalized: inference_data["confidence_interval_values_normalized"],
        topic_id: inference_data["topic_id"],
        timestamp: inference_data["timestamp"],
        extra_data: inference_data["extra_data"]
      }
    }}
  end

  def after_focus(%{"error" => error} = response) do
    Logger.debug("Allora GetInference after_focus error: #{inspect(response)}")
    Logger.error("Failed to fetch inference data from Allora API (chain_id: #{Allora.chain_id()}) - Error: #{inspect(error)}")
    {:error, error}
  end
end

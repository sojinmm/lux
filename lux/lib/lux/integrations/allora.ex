defmodule Lux.Integrations.Allora do
  @moduledoc """
  Integration module for Allora API.
  Handles configuration, authentication, and common functionality for Allora lenses.
  """

  require Logger

  @doc """
  Gets the configured Allora base URL.
  Defaults to "https://api.upshot.xyz/v2" if not configured.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://api.upshot.xyz/v2")
  end

  @doc """
  Gets the configured Allora chain slug.
  Defaults to "testnet" if not configured.
  """
  @spec chain_slug() :: String.t()
  def chain_slug do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:chain_slug, "testnet")
  end

  @doc """
  Gets the chain ID based on the configured chain slug.
  Returns "allora-testnet-1" for testnet and "allora-mainnet-1" for mainnet.
  """
  @spec chain_id() :: String.t()
  def chain_id do
    case chain_slug() do
      "mainnet" -> "allora-mainnet-1"
      _ -> "allora-testnet-1"
    end
  end

  @doc """
  Gets the default headers for Allora API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Gets the authentication configuration for Allora API requests.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :api_key,
      key: &__MODULE__.api_key/0
    }
  end

  @doc """
  Authenticates a lens for Allora API requests.
  Only adds the x-api-key header if it's not already present.
  """
  @spec authenticate(map()) :: map()
  def authenticate(%{headers: headers} = lens) do
    case Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-api-key" end) do
      nil ->
        %{lens | headers: [{"x-api-key", api_key()} | headers]}
      _ ->
        lens
    end
  end

  # Gets the Allora API key from configuration.
  # Raises if the key is not configured.
  @spec api_key() :: String.t()
  def api_key do
    :lux
    |> Application.get_env(__MODULE__)
    |> Keyword.get(:api_key)
  end
end

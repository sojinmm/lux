defmodule Lux.Integrations.Discord.Client do
  @moduledoc """
  Basic HTTP client for Discord API requests.
  """

  require Logger

  @endpoint "https://discord.com/api/v10"

  @doc """
  Makes a request to the Discord API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/channels/123")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Discord API token (required)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include

  ## Examples

      iex> Discord.Client.request(:get, "/users/@me", token: "your_token")
      {:ok, %{"id" => "123", "username" => "bot"}}

      iex> Discord.Client.request(:post, "/channels/123/messages", token: "your_token", json: %{content: "Hello!"})
      {:ok, %{"id" => "456", "content" => "Hello!"}}

  """
  @spec request(atom(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || Lux.Config.discord_token()

    [
      method: method,
      url: @endpoint <> path,
      headers: [
        {"Authorization", build_auth_header(token)},
        {"Content-Type", "application/json"}
      ],
      json: opts[:json]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: status, body: %{"message" => message}}} ->
        {:error, {status, message}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_auth_header(token) do
    cond do
      String.starts_with?(token, "Bot ") -> token
      String.starts_with?(token, "Bearer ") -> token
      true -> "Bot #{token}"
    end
  end
end

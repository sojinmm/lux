defmodule Lux.Integrations.Discord.Client do
  @moduledoc """
  Basic HTTP client for Discord API requests.
  Handles authentication and provides a simple interface for making requests to the Discord API.
  """

  @base_url "https://discord.com/api/v10"
  @default_max_retries 3
  @default_retry_delay 1000

  def request(method, path, opts \\ []) do
    url = @base_url <> path
    headers = build_headers(opts[:headers])
    retry_opts = %{
      max_retries: opts[:max_retries] || @default_max_retries,
      current_retry: 0
    }

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      json: opts[:json]
    ]
    |> maybe_add_test_config()

    do_request(req_opts, retry_opts)
  end

  defp do_request(req_opts, %{current_retry: current_retry, max_retries: max_retries} = retry_opts) do
    case Req.request(req_opts) |> handle_response() do
      {:ok, _body} = response ->
        response
      {:error, %{"retry_after" => retry_after}} when current_retry < max_retries ->
        Process.sleep(retry_after)
        do_request(req_opts, %{retry_opts | current_retry: current_retry + 1})
      {:error, _body} = _error when current_retry < max_retries ->
        Process.sleep(@default_retry_delay)
        do_request(req_opts, %{retry_opts | current_retry: current_retry + 1})
      error ->
        error
    end
  end

  defp maybe_add_test_config(req_opts) do
    if Mix.env() == :test do
      Keyword.merge(req_opts, plug: {Req.Test, :discord_client})
    else
      req_opts
    end
  end

  defp build_headers(additional_headers) do
    token = get_discord_token()
    [
      {"Authorization", "Bot #{token}"},
      {"Content-Type", "application/json"}
    ] ++ (additional_headers || [])
  end

  defp get_discord_token do
    Application.get_env(:lux, :api_keys)[:discord] ||
      raise "Discord bot token is not configured! Please set it in your config."
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, response}) do
    {:error, response.body}
  end

  defp handle_response({:error, _reason} = error) do
    error
  end
end

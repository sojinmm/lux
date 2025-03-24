defmodule Lux.Lenses.DiscordLens do
  @moduledoc """
  Handles all Discord API interactions for agents.
  This lens serves as a unified interface for all Discord API endpoints.

  ## Examples

  ```elixir
  # Reading channel messages
  DiscordLens.focus(%{
    endpoint: "/channels/:channel_id/messages",
    params: %{
      channel_id: "123456789",
      limit: 50
    }
  })

  # Sending a message
  DiscordLens.focus(%{
    endpoint: "/channels/:channel_id/messages",
    params: %{
      channel_id: "123456789",
      content: "Hello, how can I help you?"
    },
    method: :post
  })

  # Getting server information
  DiscordLens.focus(%{
    endpoint: "/guilds/:guild_id",
    params: %{guild_id: "987654321"}
  })
  ```
  """

  use Lux.Lens,
    name: "Discord API",
    description: "Handles all Discord API interactions for agents",
    url: "https://discord.com/api/v10",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_bot_token/1
    }

  def add_bot_token(lens) do
    token = Lux.Config.discord_bot_token()
    %{lens | headers: lens.headers ++ [{"Authorization", "Bot #{token}"}]}
  end

  def before_focus(lens, %{endpoint: endpoint} = input) do
    # Get params if they exist
    params = Map.get(input, :params, %{})

    # Process URL parameters (e.g., :channel_id -> actual channel ID)
    url = Enum.reduce(params, endpoint, fn {key, value}, acc ->
      String.replace(acc, ":#{key}", to_string(value))
    end)

    # Set HTTP method (default: GET)
    method = Map.get(input, :method, :get)

    # Generate final URL
    full_url = lens.url <> url

    # Handle request parameters based on HTTP method
    lens = %{lens | url: full_url, method: method}

    case method do
      :get ->
        # For GET requests, use query parameters
        query_params = params
        |> Map.drop([:channel_id, :guild_id, :user_id])
        |> Map.drop([:method, :endpoint])
        %{lens | params: query_params}
      _ ->
        # For other methods, use body
        body = Map.get(input, :body) || params
        |> Map.drop([:channel_id, :guild_id, :user_id])
        |> Map.drop([:method, :endpoint])
        %{lens | body: body}
    end
  end

  @doc """
  Processes Discord API responses.

  ## Examples

      iex> after_focus(%{"id" => "123", "content" => "Hello"})
      {:ok, %{"id" => "123", "content" => "Hello"}}

      iex> after_focus(%{"code" => 50001, "message" => "Missing Access"})
      {:error, "Discord API Error 50001: Missing Access"}
  """
  def after_focus(%{"code" => code, "message" => message}) do
    {:error, "Discord API Error #{code}: #{message}"}
  end

  def after_focus(%{"retry_after" => retry_after}) do
    {:error, "Rate limited. Try again after #{retry_after} seconds"}
  end

  def after_focus(response) do
    {:ok, response}
  end
end

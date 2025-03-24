defmodule Lux.Prisms.Discord.Messages.ReadChannelMessagesPrism do
  @moduledoc """
  A prism for reading messages from a Discord channel.

  ## Examples
      iex> ReadChannelMessagesPrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   limit: 50
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{messages: [%{content: "Hello!"}]}}
  """

  use Lux.Prism,
    name: "Read Discord Channel Messages",
    description: "Reads messages from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to read messages from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to retrieve (default: 50)",
          minimum: 1,
          maximum: 100,
          default: 50
        },
        before: %{
          type: :string,
          description: "Get messages before this message ID",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "Get messages after this message ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        messages: %{
          type: :array,
          description: "List of messages retrieved from the channel",
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string, description: "Message ID"},
              content: %{type: :string, description: "Message content"},
              author: %{
                type: :object,
                properties: %{
                  id: %{type: :string, description: "Author's Discord ID"},
                  username: %{type: :string, description: "Author's username"}
                }
              },
              timestamp: %{type: :string, description: "Message timestamp"}
            }
          }
        }
      },
      required: ["messages"]
    }

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    50001 => "Missing access",
    50013 => "Missing permissions",
    50035 => "Invalid form body",
    10008 => "Unknown message",
    30001 => "Maximum number of messages reached",
    50016 => "Rate limited"
  }

  @doc """
  Handles the request to read messages from a Discord channel.
  """
  def handler(%{channel_id: channel_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} reading messages from channel #{channel_id}")

    params = Map.take(input, [:limit, :before, :after])

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/messages",
      method: :get,
      params: params
    }) do
      {:ok, messages} ->
        Logger.info("Successfully retrieved #{length(messages)} messages from channel #{channel_id}")
        {:ok, %{messages: messages}}

      {:error, reason} ->
        Logger.error("Failed to fetch Discord messages: #{inspect(reason)}")
        handle_discord_error(reason)
    end
  end

  @doc """
  Validates the input parameters.
  """
  def validate(input) do
    if not Map.has_key?(input, :channel_id) do
      {:error, "Missing required field: channel_id"}
    else
      with {:ok, _} <- validate_channel_id(input.channel_id),
           {:ok, _} <- validate_limit(input[:limit]),
           {:ok, _} <- validate_before(input[:before]),
           {:ok, _} <- validate_after(input[:after]) do
        :ok
      end
    end
  end

  defp validate_channel_id(channel_id) when is_binary(channel_id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, channel_id) do
      {:ok, channel_id}
    else
      {:error, "channel_id must be a valid Discord ID (17-20 digits)"}
    end
  end
  defp validate_channel_id(_), do: {:error, "channel_id must be a string"}

  defp validate_limit(nil), do: {:ok, nil}
  defp validate_limit(limit) when is_integer(limit) and limit in 1..100, do: {:ok, limit}
  defp validate_limit(_), do: {:error, "limit must be an integer between 1 and 100"}

  defp validate_before(nil), do: {:ok, nil}
  defp validate_before(id) when is_binary(id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, id) do
      {:ok, id}
    else
      {:error, "before must be a valid Discord message ID (17-20 digits)"}
    end
  end
  defp validate_before(_), do: {:error, "before must be a string"}

  defp validate_after(nil), do: {:ok, nil}
  defp validate_after(id) when is_binary(id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, id) do
      {:ok, id}
    else
      {:error, "after must be a valid Discord message ID (17-20 digits)"}
    end
  end
  defp validate_after(_), do: {:error, "after must be a string"}

  defp handle_discord_error(%{"code" => code} = error) do
    error_message = @discord_errors[code] || "Unknown Discord error"
    {:error, "#{error_message} (code: #{code}): #{error["message"]}"}
  end
  defp handle_discord_error(error), do: {:error, "Unexpected error: #{inspect(error)}"}
end

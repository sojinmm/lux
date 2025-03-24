defmodule Lux.Prisms.Discord.Messages.GetPinnedMessagesPrism do
  @moduledoc """
  A prism for retrieving pinned messages from a Discord channel.

  ## Examples
      iex> GetPinnedMessagesPrism.handler(%{
      ...>   channel_id: "123456789"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{messages: [%{id: "987654321", content: "Important message"}]}}
  """

  use Lux.Prism,
    name: "Get Pinned Discord Messages",
    description: "Retrieves all pinned messages from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to get pinned messages from",
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
          description: "List of pinned messages",
          items: %{
            type: :object,
            properties: %{
              id: %{
                type: :string,
                description: "Message ID"
              },
              content: %{
                type: :string,
                description: "Message content"
              },
              channel_id: %{
                type: :string,
                description: "Channel ID where the message is pinned"
              },
              author: %{
                type: :object,
                properties: %{
                  id: %{type: :string, description: "Author's Discord ID"},
                  username: %{type: :string, description: "Author's username"},
                  discriminator: %{type: :string, description: "Author's discriminator"},
                  avatar: %{type: :string, description: "Author's avatar hash"}
                }
              },
              timestamp: %{
                type: :string,
                description: "When the message was originally sent"
              },
              pinned_timestamp: %{
                type: :string,
                description: "When the message was pinned"
              }
            },
            required: ["id", "content", "author", "timestamp"]
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
    50035 => "Invalid form body"
  }

  @doc """
  Handles the request to get pinned messages from a Discord channel.
  """
  def handler(%{channel_id: channel_id}, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} retrieving pinned messages from channel #{channel_id}")

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/pins",
      method: :get
    }) do
      {:ok, messages} when is_list(messages) ->
        Logger.info("Successfully retrieved #{length(messages)} pinned messages from channel #{channel_id}")
        {:ok, %{messages: messages}}

      {:error, reason} ->
        Logger.error("Failed to retrieve pinned Discord messages: #{inspect(reason)}")
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
      with {:ok, _} <- validate_channel_id(input.channel_id) do
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

  defp handle_discord_error(%{"code" => code} = error) do
    error_message = @discord_errors[code] || "Unknown Discord error"
    {:error, "#{error_message} (code: #{code}): #{error["message"]}"}
  end
  defp handle_discord_error(error), do: {:error, "Unexpected error: #{inspect(error)}"}
end

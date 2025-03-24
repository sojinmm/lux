defmodule Lux.Prisms.Discord.Messages.ReactToMessagePrism do
  @moduledoc """
  A prism for adding reactions to messages in a Discord channel.
  Supports both Unicode emojis and custom emojis.

  ## Examples
      # React with Unicode emoji
      iex> ReactToMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   emoji: "👍"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{reacted: true}}

      # React with custom emoji
      iex> ReactToMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   emoji: "custom_emoji:123456789"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{reacted: true}}
  """

  use Lux.Prism,
    name: "React to Discord Message",
    description: "Adds a reaction to a message in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the message",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to react to",
          pattern: "^[0-9]{17,20}$"
        },
        emoji: %{
          type: :string,
          description: "The emoji to react with (Unicode emoji or custom emoji ID)",
          minLength: 1,
          maxLength: 32
        }
      },
      required: ["channel_id", "message_id", "emoji"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        reacted: %{
          type: :boolean,
          description: "Whether the reaction was successfully added"
        },
        emoji: %{
          type: :string,
          description: "The emoji that was used"
        }
      },
      required: ["reacted"]
    }

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    10008 => "Unknown message",
    10014 => "Unknown emoji",
    50001 => "Missing access",
    50013 => "Missing permissions",
    50021 => "Cannot execute action on this channel type",
    90001 => "Reaction blocked"
  }

  @doc """
  Handles the request to add a reaction to a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id, emoji: emoji}, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} adding reaction #{emoji} to message #{message_id} in channel #{channel_id}")

    # URL encode the emoji
    encoded_emoji = URI.encode(emoji)

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded_emoji}/@me",
      method: :put
    }) do
      {:ok, _} ->
        Logger.info("Successfully added reaction #{emoji} to message #{message_id}")
        {:ok, %{
          reacted: true,
          emoji: emoji
        }}

      {:error, reason} ->
        Logger.error("Failed to add reaction to Discord message: #{inspect(reason)}")
        handle_discord_error(reason)
    end
  end

  @doc """
  Validates the input parameters.
  """
  def validate(input) do
    if not (Map.has_key?(input, :channel_id) and Map.has_key?(input, :message_id) and Map.has_key?(input, :emoji)) do
      {:error, "Missing required fields: channel_id, message_id, emoji"}
    else
      with {:ok, _} <- validate_channel_id(input.channel_id),
           {:ok, _} <- validate_message_id(input.message_id),
           {:ok, _} <- validate_emoji(input.emoji) do
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

  defp validate_message_id(message_id) when is_binary(message_id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, message_id) do
      {:ok, message_id}
    else
      {:error, "message_id must be a valid Discord ID (17-20 digits)"}
    end
  end
  defp validate_message_id(_), do: {:error, "message_id must be a string"}

  defp validate_emoji(emoji) when is_binary(emoji) do
    cond do
      String.length(emoji) < 1 ->
        {:error, "emoji must not be empty"}
      String.length(emoji) > 32 ->
        {:error, "emoji must not exceed 32 characters"}
      true ->
        {:ok, emoji}
    end
  end
  defp validate_emoji(_), do: {:error, "emoji must be a string"}

  defp handle_discord_error(%{"code" => code} = error) do
    error_message = @discord_errors[code] || "Unknown Discord error"
    {:error, "#{error_message} (code: #{code}): #{error["message"]}"}
  end
  defp handle_discord_error(error), do: {:error, "Unexpected error: #{inspect(error)}"}
end

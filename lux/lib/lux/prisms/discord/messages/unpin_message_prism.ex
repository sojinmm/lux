defmodule Lux.Prisms.Discord.Messages.UnpinMessagePrism do
  @moduledoc """
  A prism for unpinning messages in a Discord channel.

  ## Examples
      iex> UnpinMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{unpinned: true}}
  """

  use Lux.Prism,
    name: "Unpin Discord Message",
    description: "Unpins a message in a Discord channel",
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
          description: "The ID of the message to unpin",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "The reason for unpinning the message (appears in audit log)",
          maxLength: 512
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unpinned: %{
          type: :boolean,
          description: "Whether the message was successfully unpinned"
        },
        message_id: %{
          type: :string,
          description: "The ID of the unpinned message"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID where the message was unpinned"
        }
      },
      required: ["unpinned"]
    }

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    10008 => "Unknown message",
    50001 => "Missing access",
    50013 => "Missing permissions",
    50019 => "Cannot unpin message in this channel",
    50035 => "Invalid form body",
    10062 => "Message is not pinned"
  }

  @doc """
  Handles the request to unpin a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} unpinning message #{message_id} in channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/pins/#{message_id}",
      method: :delete,
      headers: headers
    }) do
      {:ok, _} ->
        Logger.info("Successfully unpinned message #{message_id} in channel #{channel_id}")
        {:ok, %{
          unpinned: true,
          message_id: message_id,
          channel_id: channel_id
        }}

      {:error, reason} ->
        Logger.error("Failed to unpin Discord message: #{inspect(reason)}")
        handle_discord_error(reason)
    end
  end

  @doc """
  Validates the input parameters.
  """
  def validate(input) do
    if not (Map.has_key?(input, :channel_id) and Map.has_key?(input, :message_id)) do
      {:error, "Missing required fields: channel_id, message_id"}
    else
      with {:ok, _} <- validate_channel_id(input.channel_id),
           {:ok, _} <- validate_message_id(input.message_id),
           {:ok, _} <- validate_reason(input[:reason]) do
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

  defp validate_reason(nil), do: {:ok, nil}
  defp validate_reason(reason) when is_binary(reason) do
    if String.length(reason) <= 512 do
      {:ok, reason}
    else
      {:error, "reason must not exceed 512 characters"}
    end
  end
  defp validate_reason(_), do: {:error, "reason must be a string"}

  defp handle_discord_error(%{"code" => code} = error) do
    error_message = @discord_errors[code] || "Unknown Discord error"
    {:error, "#{error_message} (code: #{code}): #{error["message"]}"}
  end
  defp handle_discord_error(error), do: {:error, "Unexpected error: #{inspect(error)}"}
end

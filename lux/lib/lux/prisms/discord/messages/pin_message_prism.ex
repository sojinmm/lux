defmodule Lux.Prisms.Discord.Messages.PinMessagePrism do
  @moduledoc """
  A prism for pinning messages in a Discord channel.

  ## Examples
      iex> PinMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{pinned: true}}
  """

  use Lux.Prism,
    name: "Pin Discord Message",
    description: "Pins a message in a Discord channel",
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
          description: "The ID of the message to pin",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "The reason for pinning the message (appears in audit log)",
          maxLength: 512
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pinned: %{
          type: :boolean,
          description: "Whether the message was successfully pinned"
        },
        message_id: %{
          type: :string,
          description: "The ID of the pinned message"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID where the message was pinned"
        }
      },
      required: ["pinned"]
    }

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    10008 => "Unknown message",
    50001 => "Missing access",
    50013 => "Missing permissions",
    50019 => "Cannot pin message in this channel",
    50035 => "Invalid form body",
    30003 => "Maximum number of pins reached (50)"
  }

  @doc """
  Handles the request to pin a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} pinning message #{message_id} in channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/pins/#{message_id}",
      method: :put,
      headers: headers
    }) do
      {:ok, _} ->
        Logger.info("Successfully pinned message #{message_id} in channel #{channel_id}")
        {:ok, %{
          pinned: true,
          message_id: message_id,
          channel_id: channel_id
        }}

      {:error, reason} ->
        Logger.error("Failed to pin Discord message: #{inspect(reason)}")
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

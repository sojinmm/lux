defmodule Lux.Prisms.Discord.Messages.BulkDeleteMessagesPrism do
  @moduledoc """
  A prism for bulk deleting messages in a Discord channel.
  Messages must be between 2 weeks old and 2 seconds old to be deleted.
  Can delete between 2 and 100 messages at once.

  ## Examples
      iex> BulkDeleteMessagesPrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_ids: ["987654321", "987654322", "987654323"]
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{deleted: true, count: 3}}
  """

  use Lux.Prism,
    name: "Bulk Delete Discord Messages",
    description: "Deletes multiple messages in a Discord channel at once",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel containing the messages",
          pattern: "^[0-9]{17,20}$"
        },
        message_ids: %{
          type: :array,
          description: "List of message IDs to delete (2-100 messages, not older than 2 weeks)",
          items: %{
            type: :string,
            pattern: "^[0-9]{17,20}$"
          },
          minItems: 2,
          maxItems: 100
        },
        reason: %{
          type: :string,
          description: "The reason for deleting the messages (appears in audit log)",
          maxLength: 512
        }
      },
      required: ["channel_id", "message_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the messages were successfully deleted"
        },
        count: %{
          type: :integer,
          description: "Number of messages deleted"
        }
      },
      required: ["deleted", "count"]
    }

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    10008 => "Unknown message",
    50001 => "Missing access",
    50013 => "Missing permissions",
    50034 => "Messages provided are too old for bulk deletion",
    50035 => "Invalid form body",
    50021 => "Cannot execute action on this channel type"
  }

  @doc """
  Handles the request to bulk delete messages in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_ids: message_ids} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} bulk deleting #{length(message_ids)} messages in channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/messages/bulk-delete",
      method: :post,
      body: %{messages: message_ids},
      headers: headers
    }) do
      {:ok, _} ->
        count = length(message_ids)
        Logger.info("Successfully deleted #{count} messages in channel #{channel_id}")
        {:ok, %{
          deleted: true,
          count: count
        }}

      {:error, reason} ->
        Logger.error("Failed to bulk delete Discord messages: #{inspect(reason)}")
        handle_discord_error(reason)
    end
  end

  @doc """
  Validates the input parameters.
  """
  def validate(input) do
    if not (Map.has_key?(input, :channel_id) and Map.has_key?(input, :message_ids)) do
      {:error, "Missing required fields: channel_id, message_ids"}
    else
      with {:ok, _} <- validate_channel_id(input.channel_id),
           {:ok, _} <- validate_message_ids(input.message_ids) do
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

  defp validate_message_ids(message_ids) when is_list(message_ids) do
    cond do
      length(message_ids) < 2 ->
        {:error, "Must provide at least 2 message IDs"}
      length(message_ids) > 100 ->
        {:error, "Cannot delete more than 100 messages at once"}
      not Enum.all?(message_ids, &is_binary/1) ->
        {:error, "All message IDs must be strings"}
      not Enum.all?(message_ids, &Regex.match?(~r/^[0-9]{17,20}$/, &1)) ->
        {:error, "All message IDs must be valid Discord IDs (17-20 digits)"}
      true ->
        {:ok, message_ids}
    end
  end
  defp validate_message_ids(_), do: {:error, "message_ids must be a list"}

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

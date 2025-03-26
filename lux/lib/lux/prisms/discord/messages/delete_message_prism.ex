defmodule Lux.Prisms.Discord.Messages.DeleteMessagePrism do
  @moduledoc """
  A prism for deleting messages from a Discord channel.

  ## Examples
      iex> DeleteMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{deleted: true}}
  """

  use Lux.Prism,
    name: "Delete Discord Message",
    description: "Deletes a message from a Discord channel",
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
          description: "The ID of the message to delete",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "The reason for deleting the message (appears in audit log)",
          maxLength: 512
        }
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the message was successfully deleted"
        },
        message_id: %{
          type: :string,
          description: "The ID of the deleted message"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID where the message was deleted"
        }
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to delete a message from a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} deleting message #{message_id} from channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}", headers: headers) do
      {:ok, _} ->
        Logger.info("Successfully deleted message #{message_id} from channel #{channel_id}")
        {:ok, %{deleted: true, message_id: message_id, channel_id: channel_id}}
      error -> error
    end
  end
end

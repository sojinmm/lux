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

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to bulk delete messages in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_ids: message_ids} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} bulk deleting #{length(message_ids)} messages in channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete",
      json: %{messages: message_ids},
      headers: headers
    ) do
      {:ok, _} ->
        count = length(message_ids)
        Logger.info("Successfully deleted #{count} messages in channel #{channel_id}")
        {:ok, %{deleted: true, count: count}}
      error -> error
    end
  end
end

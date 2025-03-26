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

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to unpin a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} unpinning message #{message_id} in channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case Client.request(:delete, "/channels/#{channel_id}/pins/#{message_id}", headers: headers) do
      {:ok, _} ->
        Logger.info("Successfully unpinned message #{message_id} in channel #{channel_id}")
        {:ok, %{unpinned: true, message_id: message_id, channel_id: channel_id}}
      error -> error
    end
  end
end

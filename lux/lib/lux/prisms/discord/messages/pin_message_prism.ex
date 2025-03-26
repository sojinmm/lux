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

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to pin a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} pinning message #{message_id} in channel #{channel_id}")

    headers = if input[:reason], do: [{"X-Audit-Log-Reason", input.reason}], else: []

    case Client.request(:put, "/channels/#{channel_id}/pins/#{message_id}", headers: headers) do
      {:ok, _} ->
        Logger.info("Successfully pinned message #{message_id} in channel #{channel_id}")
        {:ok, %{pinned: true, message_id: message_id, channel_id: channel_id}}
      error -> error
    end
  end
end

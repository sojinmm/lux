defmodule Lux.Prisms.Discord.Messages.PinMessagePrism do
  @moduledoc """
  A prism for pinning messages in a Discord channel.

  This prism provides a simple interface for pinning Discord messages with:
  - Minimal required parameters (channel_id, message_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

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
        }
      },
      required: ["pinned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to pin a message in a Discord channel.

  Returns {:ok, %{pinned: true}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(%{channel_id: channel_id, message_id: message_id} = params, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} pinning message #{message_id} in channel #{channel_id}")

    case Client.request(:put, "/channels/#{channel_id}/pins/#{message_id}", Map.take(params, [:plug])) do
      {:ok, _} ->
        Logger.info("Successfully pinned message #{message_id} in channel #{channel_id}")
        {:ok, %{pinned: true}}
      error -> error
    end
  end
end

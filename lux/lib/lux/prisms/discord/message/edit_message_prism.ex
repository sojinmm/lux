defmodule Lux.Prisms.Discord.Messages.EditMessagePrism do
  @moduledoc """
  A prism for editing messages in a Discord channel.

  This prism provides a simple interface for editing Discord messages with:
  - Minimal required parameters (channel_id, message_id, content)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> EditMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   content: "Updated message content"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{edited: true}}
  """

  use Lux.Prism,
    name: "Edit Discord Message",
    description: "Edits a message in a Discord channel",
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
          description: "The ID of the message to edit",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The new content for the message",
          minLength: 1,
          maxLength: 2000
        }
      },
      required: ["channel_id", "message_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        edited: %{
          type: :boolean,
          description: "Whether the message was successfully edited"
        }
      },
      required: ["edited"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to edit a message in a Discord channel.

  Returns {:ok, %{edited: true}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(%{channel_id: channel_id, message_id: message_id, content: content} = params, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} editing message #{message_id} in channel #{channel_id}")

    case Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}",
         Map.take(params, [:json, :plug]) |> Map.put(:json, %{content: content})) do
      {:ok, _response} ->
        Logger.info("Successfully edited message #{message_id} in channel #{channel_id}")
        {:ok, %{edited: true}}
      error -> error
    end
  end
end

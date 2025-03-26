defmodule Lux.Prisms.Discord.Messages.EditMessagePrism do
  @moduledoc """
  A prism for editing messages in a Discord channel.

  ## Examples
      iex> EditMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   content: "Updated message content"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{message: %{id: "987654321", content: "Updated message content"}}}
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
        message: %{
          type: :object,
          properties: %{
            id: %{type: :string, description: "Message ID"},
            content: %{type: :string, description: "Updated message content"},
            channel_id: %{type: :string, description: "Channel ID where message was edited"},
            edited_timestamp: %{type: :string, description: "When the message was edited"},
            author: %{
              type: :object,
              properties: %{
                id: %{type: :string, description: "Author's Discord ID"},
                username: %{type: :string, description: "Author's username"}
              }
            }
          },
          required: ["id", "content", "edited_timestamp"]
        }
      },
      required: ["message"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to edit a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id, content: content}, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} editing message #{message_id} in channel #{channel_id}")

    case Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", json: %{content: content}) do
      {:ok, response} ->
        Logger.info("Successfully edited message #{message_id} in channel #{channel_id}")
        {:ok, %{message: response}}
      error -> error
    end
  end
end

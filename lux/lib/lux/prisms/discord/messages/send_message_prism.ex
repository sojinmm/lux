defmodule Lux.Prisms.Discord.Messages.SendMessagePrism do
  @moduledoc """
  A prism for sending messages to a Discord channel.

  ## Examples
      iex> SendMessagePrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   content: "Hello!"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{message: %{id: "987654321", content: "Hello!"}}}
  """

  use Lux.Prism,
    name: "Send Discord Message",
    description: "Sends a message to a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to send the message to",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "The message content to send",
          minLength: 1,
          maxLength: 2000
        },
        tts: %{
          type: :boolean,
          description: "Whether to send as text-to-speech message",
          default: false
        },
        reference_id: %{
          type: :string,
          description: "ID of the message to reply to",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          properties: %{
            id: %{type: :string, description: "Message ID"},
            content: %{type: :string, description: "Message content"},
            channel_id: %{type: :string, description: "Channel ID where message was sent"},
            author: %{
              type: :object,
              properties: %{
                id: %{type: :string, description: "Author's Discord ID"},
                username: %{type: :string, description: "Author's username"}
              }
            },
            timestamp: %{type: :string, description: "Message timestamp"},
            referenced_message: %{
              type: :object,
              description: "The message that was replied to, if any",
              properties: %{
                id: %{type: :string, description: "Referenced message ID"}
              }
            }
          },
          required: ["id", "content", "channel_id"]
        }
      },
      required: ["message"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to send a message to a Discord channel.
  """
  def handler(%{channel_id: channel_id, content: content} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} sending message to channel #{channel_id}")

    message_params = %{
      content: content,
      tts: input[:tts] || false
    }
    |> maybe_add_reference(input[:reference_id])

    case Client.request(:post, "/channels/#{channel_id}/messages", json: message_params) do
      {:ok, response} ->
        Logger.info("Successfully sent message to channel #{channel_id}")
        {:ok, %{message: response}}
      error -> error
    end
  end

  defp maybe_add_reference(params, nil), do: params
  defp maybe_add_reference(params, reference_id) do
    Map.put(params, :message_reference, %{message_id: reference_id})
  end
end

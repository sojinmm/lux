defmodule Lux.Prisms.Discord.Messages.GetPinnedMessagesPrism do
  @moduledoc """
  A prism for retrieving pinned messages from a Discord channel.

  ## Examples
      iex> GetPinnedMessagesPrism.handler(%{
      ...>   channel_id: "123456789"
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{messages: [%{id: "987654321", content: "Important message"}]}}
  """

  use Lux.Prism,
    name: "Get Pinned Discord Messages",
    description: "Retrieves all pinned messages from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to get pinned messages from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        messages: %{
          type: :array,
          description: "List of pinned messages",
          items: %{
            type: :object,
            properties: %{
              id: %{
                type: :string,
                description: "Message ID"
              },
              content: %{
                type: :string,
                description: "Message content"
              },
              channel_id: %{
                type: :string,
                description: "Channel ID where the message is pinned"
              },
              author: %{
                type: :object,
                properties: %{
                  id: %{type: :string, description: "Author's Discord ID"},
                  username: %{type: :string, description: "Author's username"},
                  discriminator: %{type: :string, description: "Author's discriminator"},
                  avatar: %{type: :string, description: "Author's avatar hash"}
                }
              },
              timestamp: %{
                type: :string,
                description: "When the message was originally sent"
              },
              pinned_timestamp: %{
                type: :string,
                description: "When the message was pinned"
              }
            },
            required: ["id", "content", "author", "timestamp"]
          }
        }
      },
      required: ["messages"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to get pinned messages from a Discord channel.
  """
  def handler(%{channel_id: channel_id}, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} retrieving pinned messages from channel #{channel_id}")

    case Client.request(:get, "/channels/#{channel_id}/pins") do
      {:ok, messages} when is_list(messages) ->
        Logger.info("Successfully retrieved #{length(messages)} pinned messages from channel #{channel_id}")
        {:ok, %{messages: messages}}
      error -> error
    end
  end
end

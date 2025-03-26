defmodule Lux.Prisms.Discord.Messages.ReadChannelMessagesPrism do
  @moduledoc """
  A prism for reading messages from a Discord channel.

  ## Examples
      iex> ReadChannelMessagesPrism.handler(%{
      ...>   channel_id: "123456789",
      ...>   limit: 50
      ...> }, %{agent: %{name: "Agent"}})
      {:ok, %{messages: [%{content: "Hello!"}]}}
  """

  use Lux.Prism,
    name: "Read Discord Channel Messages",
    description: "Reads messages from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to read messages from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to retrieve (default: 50)",
          minimum: 1,
          maximum: 100,
          default: 50
        },
        before: %{
          type: :string,
          description: "Get messages before this message ID",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "Get messages after this message ID",
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
          description: "List of messages retrieved from the channel",
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string, description: "Message ID"},
              content: %{type: :string, description: "Message content"},
              author: %{
                type: :object,
                properties: %{
                  id: %{type: :string, description: "Author's Discord ID"},
                  username: %{type: :string, description: "Author's username"}
                }
              },
              timestamp: %{type: :string, description: "Message timestamp"}
            }
          }
        }
      },
      required: ["messages"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to read messages from a Discord channel.
  """
  def handler(%{channel_id: channel_id} = input, %{agent: agent} = _ctx) do
    Logger.info("Agent #{agent.name} reading messages from channel #{channel_id}")

    params = Map.take(input, [:limit, :before, :after])

    case Client.request(:get, "/channels/#{channel_id}/messages", params: params) do
      {:ok, messages} ->
        Logger.info("Successfully retrieved #{length(messages)} messages from channel #{channel_id}")
        {:ok, %{messages: messages}}
      error -> error
    end
  end
end

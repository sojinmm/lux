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

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    50001 => "Missing access",
    50013 => "Missing permissions",
    50006 => "Cannot send empty message",
    50035 => "Invalid form body",
    10008 => "Unknown message",
    50016 => "Rate limited",
    40005 => "Request entity too large",
    50007 => "Cannot send messages to this user",
    50008 => "Cannot send messages in a voice channel"
  }

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

    case DiscordLens.focus(%{
      endpoint: "/channels/#{channel_id}/messages",
      method: :post,
      body: message_params
    }) do
      {:ok, response} ->
        Logger.info("Successfully sent message to channel #{channel_id}")
        {:ok, %{message: response}}
      {:error, reason} ->
        Logger.error("Failed to send Discord message: #{inspect(reason)}")
        handle_discord_error(reason)
    end
  end

  @doc """
  Validates the input parameters.
  """
  def validate(input) do
    # Check required fields directly
    if not (Map.has_key?(input, :channel_id) and Map.has_key?(input, :content)) do
      {:error, "Missing required fields: channel_id, content"}
    else
      with {:ok, _} <- validate_channel_id(input.channel_id),
           {:ok, _} <- validate_content(input.content),
           {:ok, _} <- validate_tts(input[:tts]) do
        :ok
      end
    end
  end

  defp validate_channel_id(channel_id) when is_binary(channel_id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, channel_id) do
      {:ok, channel_id}
    else
      {:error, "channel_id must be a valid Discord ID (17-20 digits)"}
    end
  end
  defp validate_channel_id(_), do: {:error, "channel_id must be a string"}

  defp validate_content(content) when is_binary(content) and byte_size(content) in 1..2000, do: {:ok, content}
  defp validate_content(_), do: {:error, "content must be a string between 1 and 2000 characters"}

  defp validate_tts(tts) when is_boolean(tts), do: {:ok, tts}
  defp validate_tts(_), do: {:error, "tts must be a boolean"}

  defp validate_reference_id(nil), do: {:ok, nil}
  defp validate_reference_id(id) when is_binary(id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, id) do
      {:ok, id}
    else
      {:error, "reference_id must be a valid Discord message ID (17-20 digits)"}
    end
  end
  defp validate_reference_id(_), do: {:error, "reference_id must be a string"}

  defp maybe_add_reference(params, nil), do: params
  defp maybe_add_reference(params, reference_id) do
    Map.put(params, :message_reference, %{message_id: reference_id})
  end

  defp handle_discord_error(%{"code" => code} = error) do
    error_message = @discord_errors[code] || "Unknown Discord error"
    {:error, "#{error_message} (code: #{code}): #{error["message"]}"}
  end
  defp handle_discord_error(error), do: {:error, "Unexpected error: #{inspect(error)}"}
end

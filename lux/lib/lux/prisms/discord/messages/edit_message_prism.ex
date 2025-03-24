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

  alias Lux.Lenses.DiscordLens
  require Logger

  # Discord API error codes
  @discord_errors %{
    10003 => "Unknown channel",
    10008 => "Unknown message",
    50001 => "Missing access",
    50005 => "Cannot edit this message",
    50013 => "Missing permissions",
    50035 => "Invalid form body",
    40005 => "Request entity too large",
    50006 => "Cannot send empty message"
  }

  @doc """
  Handles the request to edit a message in a Discord channel.
  """
  def handler(%{channel_id: channel_id, message_id: message_id, content: content} = input, %{agent: agent} = _ctx) do
    case validate(input) do
      :ok ->
        Logger.info("Agent #{agent.name} editing message #{message_id} in channel #{channel_id}")

        case DiscordLens.focus(%{
          endpoint: "/channels/#{channel_id}/messages/#{message_id}",
          method: :patch,
          body: %{content: content}
        }) do
          {:ok, response} ->
            Logger.info("Successfully edited message #{message_id} in channel #{channel_id}")
            {:ok, %{message: response}}
          {:error, reason} ->
            Logger.error("Failed to edit Discord message: #{inspect(reason)}")
            handle_discord_error(reason)
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates the input parameters.
  """
  def validate(input) do
    if not (Map.has_key?(input, :channel_id) and Map.has_key?(input, :message_id) and Map.has_key?(input, :content)) do
      {:error, "Missing required fields: channel_id, message_id, content"}
    else
      with {:ok, _} <- validate_channel_id(input.channel_id),
           {:ok, _} <- validate_message_id(input.message_id),
           {:ok, _} <- validate_content(input.content) do
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

  defp validate_message_id(message_id) when is_binary(message_id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, message_id) do
      {:ok, message_id}
    else
      {:error, "message_id must be a valid Discord ID (17-20 digits)"}
    end
  end
  defp validate_message_id(_), do: {:error, "message_id must be a string"}

  defp validate_content(content) when is_binary(content) do
    cond do
      String.length(content) < 1 -> {:error, "content must not be empty"}
      String.length(content) > 2000 -> {:error, "content must not exceed 2000 characters"}
      true -> {:ok, content}
    end
  end
  defp validate_content(_), do: {:error, "content must be a string"}

  defp handle_discord_error(%{"code" => code} = error) do
    error_message = @discord_errors[code] || "Unknown Discord error"
    {:error, "#{error_message} (code: #{code}): #{error["message"]}"}
  end
  defp handle_discord_error(error), do: {:error, "Unexpected error: #{inspect(error)}"}
end

defmodule Lux.Prisms.Discord.MessagesTest do
  use Lux.UnitCase, async: true
  import Mock

  alias Lux.Prisms.Discord.Messages.{
    SendMessagePrism,
    EditMessagePrism,
    DeleteMessagePrism,
    PinMessagePrism,
    UnpinMessagePrism,
    GetPinnedMessagesPrism,
    BulkDeleteMessagesPrism,
    ReactToMessagePrism
  }
  alias Lux.Lenses.DiscordLens

  @valid_channel_id "123456789012345678"
  @valid_message_id "876543210987654321"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "SendMessagePrism" do
    test "successfully sends a message" do
      message_content = "Test message"
      response = %{
        "id" => @valid_message_id,
        "content" => message_content,
        "channel_id" => @valid_channel_id
      }

      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :post,
          body: %{content: ^message_content}
        } -> {:ok, response} end
      ] do
        assert {:ok, %{message: ^response}} =
          SendMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              content: message_content
            },
            @agent_ctx
          )
      end
    end
  end

  describe "EditMessagePrism" do
    test "successfully edits a message" do
      new_content = "Updated message"
      response = %{
        "id" => @valid_message_id,
        "content" => new_content,
        "edited_timestamp" => "2024-01-01T00:00:00.000Z"
      }

      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :patch,
          body: %{content: ^new_content}
        } -> {:ok, response} end
      ] do
        assert {:ok, %{message: ^response}} =
          EditMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              message_id: @valid_message_id,
              content: new_content
            },
            @agent_ctx
          )
      end
    end
  end

  describe "DeleteMessagePrism" do
    test "successfully deletes a message" do
      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :delete
        } -> {:ok, %{}} end
      ] do
        assert {:ok, %{deleted: true}} =
          DeleteMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              message_id: @valid_message_id
            },
            @agent_ctx
          )
      end
    end
  end

  describe "PinMessagePrism" do
    test "successfully pins a message" do
      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :put
        } -> {:ok, %{}} end
      ] do
        assert {:ok, %{pinned: true}} =
          PinMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              message_id: @valid_message_id
            },
            @agent_ctx
          )
      end
    end
  end

  describe "GetPinnedMessagesPrism" do
    test "successfully retrieves pinned messages" do
      messages = [
        %{
          "id" => @valid_message_id,
          "content" => "Pinned message",
          "channel_id" => @valid_channel_id,
          "timestamp" => "2024-01-01T00:00:00.000Z"
        }
      ]

      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :get
        } -> {:ok, messages} end
      ] do
        assert {:ok, %{messages: ^messages}} =
          GetPinnedMessagesPrism.handler(
            %{channel_id: @valid_channel_id},
            @agent_ctx
          )
      end
    end
  end

  describe "BulkDeleteMessagesPrism" do
    test "successfully bulk deletes messages" do
      message_ids = ["123456789012345678", "123456789012345679"]

      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :post,
          body: %{messages: ^message_ids}
        } -> {:ok, %{}} end
      ] do
        assert {:ok, %{deleted: true, count: 2}} =
          BulkDeleteMessagesPrism.handler(
            %{
              channel_id: @valid_channel_id,
              message_ids: message_ids
            },
            @agent_ctx
          )
      end
    end
  end

  describe "ReactToMessagePrism" do
    test "successfully adds a reaction" do
      emoji = "👍"
      encoded_emoji = URI.encode(emoji)

      with_mock DiscordLens, [
        focus: fn %{
          endpoint: "/channels/" <> _,
          method: :put
        } -> {:ok, %{}} end
      ] do
        assert {:ok, %{reacted: true}} =
          ReactToMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              message_id: @valid_message_id,
              emoji: emoji
            },
            @agent_ctx
          )
      end
    end
  end

  describe "validation" do
    test "validates channel_id format" do
      with_mock DiscordLens, [
        focus: fn _request -> {:ok, %{}} end
      ] do
        assert {:error, "channel_id must be a valid Discord ID (17-20 digits)"} =
          SendMessagePrism.handler(
            %{
              channel_id: "invalid",
              content: "test"
            },
            @agent_ctx
          )
      end
    end

    test "validates message_id format" do
      with_mock DiscordLens, [
        focus: fn _request -> {:ok, %{}} end
      ] do
        assert {:error, "message_id must be a valid Discord ID (17-20 digits)"} =
          EditMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              message_id: "invalid",
              content: "test"
            },
            @agent_ctx
          )
      end
    end

    test "validates content length" do
      with_mock DiscordLens, [
        focus: fn _request -> {:ok, %{}} end
      ] do
        assert {:error, "content must not exceed 2000 characters"} =
          SendMessagePrism.handler(
            %{
              channel_id: @valid_channel_id,
              content: String.duplicate("a", 2001)
            },
            @agent_ctx
          )
      end
    end
  end
end

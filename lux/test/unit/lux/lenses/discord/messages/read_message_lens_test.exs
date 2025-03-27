defmodule Lux.Lenses.Discord.Messages.ReadMessageLensTest do
  @moduledoc """
  Test suite for the ReadMessageLens module.
  These tests verify the lens's ability to:
  - Read messages from Discord channels
  - Handle Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Messages.ReadMessageLens

  @channel_id "123456789012345678"
  @message_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads a message with text content" do
      Req.Test.stub(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @message_id,
          "channel_id" => @channel_id,
          "content" => "Hello, world!",
          "author" => %{
            "id" => "111222333444555666",
            "username" => "TestUser"
          }
        }))
      end)

      assert {:ok, response} = ReadMessageLens.focus(
        %{
          channel_id: @channel_id,
          message_id: @message_id
        }
      )

      assert response.content == "Hello, world!"
      assert response.author.id == "111222333444555666"
      assert response.author.username == "TestUser"
    end

    test "successfully reads a message with empty content" do
      Req.Test.stub(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @message_id,
          "channel_id" => @channel_id,
          "content" => "",
          "author" => %{
            "id" => "111222333444555666",
            "username" => "TestUser"
          }
        }))
      end)

      assert {:ok, response} = ReadMessageLens.focus(
        %{
          channel_id: @channel_id,
          message_id: @message_id
        }
      )

      assert response.content == ""
      assert response.author.id == "111222333444555666"
      assert response.author.username == "TestUser"
    end

    test "handles Discord API error" do
      Req.Test.stub(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Message"
        }))
      end)

      assert {:error, %{"message" => "Unknown Message"}} = ReadMessageLens.focus(
        %{
          channel_id: @channel_id,
          message_id: @message_id
        }
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      lens = ReadMessageLens.view()
      assert lens.schema.required == ["channel_id", "message_id"]
      assert Map.has_key?(lens.schema.properties, :channel_id)
      assert Map.has_key?(lens.schema.properties, :message_id)
    end
  end
end

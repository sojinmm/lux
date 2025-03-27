defmodule Lux.Prisms.Discord.Messages.EditMessagePrismTest do
  @moduledoc """
  Test suite for the EditMessagePrism module.

  These tests verify the prism's ability to:
  - Edit messages in Discord channels
  - Handle Discord API errors appropriately
  - Validate input/output schemas

  The tests use the Discord API client mock to simulate API interactions and verify:
  - Correct HTTP method (PATCH) is used
  - Proper URL construction
  - Authorization header presence
  - Response handling for both success and error cases
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Messages.EditMessagePrism

  @channel_id "123456789012345678"
  @message_id "987654321098765432"
  @content "Updated message content"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a message" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"content" => @content}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @message_id,
          "channel_id" => @channel_id,
          "content" => @content,
          "edited_timestamp" => "2024-02-08T18:22:11.925749Z",
          "author" => %{
            "id" => "111222333444555666",
            "username" => "TestBot"
          }
        }))
      end)

      assert {:ok, %{edited: true}} = EditMessagePrism.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          content: @content,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages/#{@message_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = EditMessagePrism.handler(
        %{
          channel_id: @channel_id,
          message_id: @message_id,
          content: @content,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = EditMessagePrism.view()
      assert prism.input_schema.required == ["channel_id", "message_id", "content"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :content)
    end

    test "validates output schema" do
      prism = EditMessagePrism.view()
      assert prism.output_schema.required == ["edited"]
      assert Map.has_key?(prism.output_schema.properties, :edited)
    end
  end
end

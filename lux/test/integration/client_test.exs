defmodule Lux.Integrations.Discord.ClientTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Discord.Client

  setup do
    # Set up the Discord token in the application environment
    token = "test-discord-token"
    Application.put_env(:lux, :api_keys, discord: token)
    on_exit(fn -> Application.delete_env(:lux, :api_keys) end)

    # Set up Req.Test
    Req.Test.verify_on_exit!()
    :ok
  end

  test "GET request" do
    Req.Test.expect(:discord_client, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/v10/test"
      assert List.keyfind(conn.req_headers, "authorization", 0) == {"authorization", "Bot test-discord-token"}
      assert List.keyfind(conn.req_headers, "content-type", 0) == {"content-type", "application/json"}

      Req.Test.json(conn, %{"success" => true})
    end)

    assert {:ok, %{"success" => true}} = Client.request(:get, "/test")
  end

  test "POST request" do
    Req.Test.expect(:discord_client, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/test"
      assert List.keyfind(conn.req_headers, "authorization", 0) == {"authorization", "Bot test-discord-token"}
      assert List.keyfind(conn.req_headers, "content-type", 0) == {"content-type", "application/json"}

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"data" => "test"}

      Req.Test.json(conn, %{"success" => true})
    end)

    assert {:ok, %{"success" => true}} = Client.request(:post, "/test", json: %{data: "test"})
  end

  test "PATCH request" do
    Req.Test.expect(:discord_client, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/api/v10/test"
      assert List.keyfind(conn.req_headers, "authorization", 0) == {"authorization", "Bot test-discord-token"}
      assert List.keyfind(conn.req_headers, "content-type", 0) == {"content-type", "application/json"}

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"data" => "test"}

      Req.Test.json(conn, %{"success" => true})
    end)

    assert {:ok, %{"success" => true}} = Client.request(:patch, "/test", json: %{data: "test"})
  end

  test "DELETE request" do
    Req.Test.expect(:discord_client, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/v10/test"
      assert List.keyfind(conn.req_headers, "authorization", 0) == {"authorization", "Bot test-discord-token"}
      assert List.keyfind(conn.req_headers, "content-type", 0) == {"content-type", "application/json"}

      Req.Test.json(conn, %{"success" => true})
    end)

    assert {:ok, %{"success" => true}} = Client.request(:delete, "/test")
  end

  test "handles rate limits" do
    counter = :counters.new(1, [:atomics])

    Req.Test.stub(:discord_client, fn conn ->
      assert conn.method == "GET"
      case :counters.get(counter, 1) do
        0 ->
          :counters.add(counter, 1, 1)
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(429, Jason.encode!(%{"retry_after" => 1}))
        _ ->
          Req.Test.json(conn, %{"success" => true})
      end
    end)

    assert {:ok, %{"success" => true}} = Client.request(:get, "/test")
  end

  test "handles errors" do
    Req.Test.stub(:discord_client, fn conn ->
      assert conn.method == "GET"
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(404, Jason.encode!(%{"code" => 10003, "message" => "Unknown channel"}))
    end)

    assert {:error, %{"code" => 10003, "message" => "Unknown channel"}} = Client.request(:get, "/test")
  end
end

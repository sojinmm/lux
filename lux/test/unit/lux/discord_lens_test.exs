defmodule Lux.Lenses.DiscordLensTest do
  use ExUnit.Case
  import Mock

  alias Lux.Lenses.DiscordLens

  setup do
    with_mock Lux.Config, [
      discord_bot_token: fn -> "test_bot_token" end
    ] do
      :ok
    end
  end

  describe "focus/1" do
    test "successfully makes GET request" do
      response = %{"data" => "test"}

      with_mocks([
        {Req, [], [
          new: fn _opts -> {:ok, %{}} end,
          request: fn _req, _opts ->
            {:ok, %{status: 200, body: response}}
          end
        ]},
        {Lux.Config, [], [
          discord_bot_token: fn -> "test_bot_token" end
        ]}
      ]) do
        assert {:ok, ^response} =
          DiscordLens.focus(%{
            endpoint: "/test",
            method: :get
          })
      end
    end

    test "successfully makes POST request with body" do
      request_body = %{message: "test"}
      response = %{"success" => true}

      with_mocks([
        {Req, [], [
          new: fn _opts -> {:ok, %{}} end,
          request: fn _req, [method: :get, params: %{body: ^request_body, method: :post, endpoint: "/test"}] ->
            {:ok, %{status: 200, body: response}}
          end
        ]},
        {Lux.Config, [], [
          discord_bot_token: fn -> "test_bot_token" end
        ]}
      ]) do
        assert {:ok, ^response} =
          DiscordLens.focus(%{
            endpoint: "/test",
            method: :post,
            body: request_body
          })
      end
    end

    test "handles error response" do
      error_response = %{
        "code" => 50001,
        "message" => "Missing Access"
      }

      with_mocks([
        {Req, [], [
          new: fn _opts -> {:ok, %{}} end,
          request: fn _req, _opts ->
            {:ok, %{status: 403, body: error_response}}
          end
        ]},
        {Lux.Config, [], [
          discord_bot_token: fn -> "test_bot_token" end
        ]}
      ]) do
        assert {:error, ^error_response} =
          DiscordLens.focus(%{
            endpoint: "/test",
            method: :get
          })
      end
    end

    test "handles network error" do
      with_mocks([
        {Req, [], [
          new: fn _opts -> {:ok, %{}} end,
          request: fn _req, _opts ->
            {:error, %Req.TransportError{reason: :econnrefused}}
          end
        ]},
        {Lux.Config, [], [
          discord_bot_token: fn -> "test_bot_token" end
        ]}
      ]) do
        assert {:error, error} =
          DiscordLens.focus(%{
            endpoint: "/test",
            method: :get
          })
        assert error =~ "econnrefused"
      end
    end
  end
end

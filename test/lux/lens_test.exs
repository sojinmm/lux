defmodule Lux.LensTest do
  use ExUnit.Case, async: true
  alias Lux.Lens

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "new" do
    test "creates a new lens from a map" do
      assert Lux.Lens.new(
               url: "https://weatherapi.com",
               method: :get,
               params: %{id: 1},
               name: "weather"
             ) ==
               %Lens{
                 url: "https://weatherapi.com",
                 method: :get,
                 params: %{id: 1},
                 name: "weather",
                 headers: [],
                 auth: nil,
                 description: "",
                 after_focus: nil,
                 schema: %{}
               }
    end

    test "creates a new lens from a list" do
      assert Lens.new(url: "https://weatherapi.com", method: :get, params: %{id: 1}) ==
               %Lens{
                 url: "https://weatherapi.com",
                 method: :get,
                 params: %{id: 1},
                 name: "",
                 headers: [],
                 auth: nil,
                 description: "",
                 after_focus: nil,
                 schema: %{}
               }
    end
  end

  describe "focus" do
    test "returns the body on status 200" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"celcius" => -15})
      end)

      lens = Lens.new(url: "https://weatherapi.com", method: :get)
      assert {:ok, %{"celcius" => -15}} = Lens.focus(lens)
    end
  end

  describe "authenticate" do
    test "adds api key auth header" do
      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :api_key, key: "secret-key"}
        )

      assert %Lens{headers: [{"Authorization", "Bearer secret-key"}]} = Lens.authenticate(lens)
    end

    test "adds basic auth header" do
      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :basic, username: "user", password: "pass"}
        )

      assert %Lens{headers: [{"Authorization", "Basic " <> _}]} = Lens.authenticate(lens)
    end

    test "adds oauth token header" do
      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :oauth, token: "oauth-token"}
        )

      assert %Lens{headers: [{"Authorization", "Bearer oauth-token"}]} = Lens.authenticate(lens)
    end

    test "calls custom auth function" do
      custom_auth = fn lens ->
        %Lens{lens | headers: [{"X-Custom-Auth", "custom-value"}]}
      end

      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :custom, auth_function: custom_auth}
        )

      assert %Lens{headers: [{"X-Custom-Auth", "custom-value"}]} = Lens.authenticate(lens)
    end
  end
end

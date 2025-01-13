defmodule Lux.LensTest do
  use ExUnit.Case, async: true
  alias Lux.Lens

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "new" do
    require Lux.Lens
    import Lux.Lens

    test "creates a new lens from a map" do
      assert Lux.Lens.new(
               url: "https://weatherapi.com",
               method: :get,
               params: %{id: 1},
               name: "weather"
             ) ==
               lens(
                 url: "https://weatherapi.com",
                 method: :get,
                 params: %{id: 1},
                 name: "weather"
               )
    end

    test "creates a new lens from a list" do
      assert Lens.new(url: "https://weatherapi.com", method: :get, params: %{id: 1}) ==
               Lens.new(url: "https://weatherapi.com", method: :get, params: %{id: 1})
    end
  end

  describe "focus" do
    test "returns the body on status 200" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"celcius" => -15})
      end)

      assert {:ok, %{"celcius" => -15}} =
               Lens.focus(
                 Lens.new(url: "https://weatherapi.com", method: :get, params: %{city: "Seoul"})
               )
    end

    test "return an error on http status 500" do
      Req.Test.expect(Lux.Lens, 3, fn conn ->
        Plug.Conn.send_resp(conn, 500, "internal server error")
      end)

      assert {:error, "internal server error"} =
               Lens.focus(
                 Lens.new(url: "https://weatherapi.com", method: :get, params: %{city: "Seoul"})
               )
    end

    test "returns the error on status 404" do
      Req.Test.expect(Lux.Lens, 3, &Req.Test.transport_error(&1, :econnrefused))

      assert {:error, ":econnrefused"} =
               Lens.focus(
                 Lens.new(url: "https://weatherapi.com", method: :get, params: %{city: "Seoul"})
               )
    end

    test "runs after_focus if present" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{"city" => "Seoul", "temp_c" => 1.0},
            %{"city" => "Incheon", "temp_c" => 2.0},
            %{"city" => "Busan", "temp_c" => 3.0},
            %{"city" => "Gwangju", "temp_c" => 4.0},
            %{"city" => "Daegu", "temp_c" => 5.0}
          ]
        })
      end)

      after_focus = fn %{"data" => data} ->
        {:ok,
         %{
           "everage_temp_c" =>
             data |> Enum.map(& &1["temp_c"]) |> Enum.sum() |> then(&(&1 / length(data)))
         }}
      end

      assert {:ok, %{"everage_temp_c" => 3.0}} =
               Lens.focus(
                 Lens.new(
                   url: "https://weatherapi.com",
                   method: :get,
                   params: %{country: "South Korea"},
                   after_focus: after_focus
                 )
               )
    end
  end
end

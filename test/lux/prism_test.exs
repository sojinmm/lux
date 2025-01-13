defmodule Lux.PrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prism
  require Prism

  doctest Lux.Prism, import: true

  describe "new/1" do
    test "creates a prism from a variable map" do
      attrs = %{
        id: "1",
        name: "test",
        handler: fn -> :ok end,
        description: "test",
        examples: ["test"]
      }

      assert Prism.prism(
               name: name,
               id: id,
               handler: handler,
               description: description,
               examples: examples
             ) = Prism.new(attrs)

      assert name == "test"
      assert id == "1"
      assert description == "test"
      assert examples == ["test"]
      assert is_function(handler)
    end

    test "creates a prism from a variable keyword list" do
      handler = fn -> :ok end

      attrs = [
        name: "test",
        id: "1",
        handler: handler
      ]

      assert Prism.prism(name: name, id: id, handler: handler) = Prism.new(attrs)

      assert name == "test"
      assert id == "1"
      assert is_function(handler)
    end
  end

  describe "When we `use` a Prism" do
    test "then we can call the `run` directly" do
      defmodule MyExclamationPrism do
        use Lux.Prism

        def handler(input, _ctx) do
          {:ok, input <> "!!!"}
        end
      end

      assert MyExclamationPrism.run("Hello world") == {:ok, "Hello world!!!"}
    end
  end
end

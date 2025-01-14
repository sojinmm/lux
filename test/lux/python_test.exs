defmodule Lux.PythonTest do
  use ExUnit.Case, async: true
  doctest Lux.Python

  describe "eval/2" do
    test "evaluates simple Python expressions" do
      assert {:ok, 2} = Lux.Python.eval("1 + 1")
    end

    test "evaluates code with variable bindings" do
      assert {:ok, 30} = Lux.Python.eval("x * y", variables: %{x: 5, y: 6})
    end

    test "supports multi-line code" do
      code = """
      def factorial(n):
          if n <= 1:
              return 1
          return n * factorial(n - 1)
      factorial(5)
      """

      assert {:ok, 120} = Lux.Python.eval(code)
    end

    test "handles Python imports" do
      assert {:ok, 4.0} =
               Lux.Python.eval("""
               import math
               math.sqrt(16)
               """)
    end

    test "preserves Python data types" do
      assert {:ok, %{"key" => "value", "numbers" => [1, 2, 3]}} =
               Lux.Python.eval("""
               {"key": "value", "numbers": [1, 2, 3]}
               """)
    end

    test "handles errors gracefully" do
      assert {:error, error} = Lux.Python.eval("undefined_variable")
      assert error =~ "NameError"
    end

    test "supports complex variable bindings" do
      variables = %{
        number: 42,
        list: [1, 2, 3],
        map: %{"name" => "Alice", "age" => 30},
        nested: %{
          "data" => [
            %{"id" => 1, "value" => "first"},
            %{"id" => 2, "value" => "second"}
          ]
        }
      }

      assert {:ok, 42} = Lux.Python.eval("number", variables: variables)
      assert {:ok, 6} = Lux.Python.eval("sum(list)", variables: variables)
      assert {:ok, "Alice"} = Lux.Python.eval("map['name']", variables: variables)
      assert {:ok, "first"} = Lux.Python.eval("nested['data'][0]['value']", variables: variables)
    end
  end

  describe "eval!/2" do
    test "returns result directly on success" do
      assert 2 = Lux.Python.eval!("1 + 1")
    end

    test "raises error on failure" do
      assert_raise RuntimeError, ~r/Python execution error.*NameError/, fn ->
        Lux.Python.eval!("undefined_variable")
      end
    end
  end
end

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

  describe "type conversions" do
    test "converts basic Python types to Elixir types" do
      # None -> nil
      assert {:ok, nil} = Lux.Python.eval("None")

      # Bool -> boolean
      assert {:ok, true} = Lux.Python.eval("True")
      assert {:ok, false} = Lux.Python.eval("False")

      # Int -> integer
      assert {:ok, 42} = Lux.Python.eval("42")
      assert {:ok, -17} = Lux.Python.eval("-17")

      # Float -> float
      assert {:ok, 3.14} = Lux.Python.eval("3.14")
      assert {:ok, -0.001} = Lux.Python.eval("-0.001")

      # String -> binary
      assert {:ok, "hello"} = Lux.Python.eval("'hello'")
      assert {:ok, "world"} = Lux.Python.eval("\"world\"")
      # Unicode
      assert {:ok, "🌍"} = Lux.Python.eval("'🌍'")
    end

    test "converts Python collections to Elixir collections" do
      # List -> list
      assert {:ok, [1, 2, 3]} = Lux.Python.eval("[1, 2, 3]")
      assert {:ok, ["a", "b"]} = Lux.Python.eval("['a', 'b']")

      # Tuple -> list
      assert {:ok, [1, 2]} = Lux.Python.eval("(1, 2)")

      # Dict -> map
      assert {:ok, %{"a" => 1, "b" => 2}} = Lux.Python.eval("{'a': 1, 'b': 2}")

      # Nested collections
      assert {:ok, %{"list" => [1, 2], "map" => %{"x" => 10}}} =
               Lux.Python.eval("""
               {
                 'list': [1, 2],
                 'map': {'x': 10}
               }
               """)
    end

    test "converts Python dicts with __class__ to Elixir structs" do
      # Basic struct conversion
      assert {:ok, %{__struct__: User, name: "Alice"}} =
               Lux.Python.eval("""
               {'__class__': 'user', 'name': 'Alice'}
               """)

      # Nested module name
      assert {:ok, %{__struct__: Data.Types.Point, x: 1, y: 2}} =
               Lux.Python.eval("""
               {'__class__': 'data.types.point', 'x': 1, 'y': 2}
               """)

      # Struct with nested collections
      assert {:ok,
              %{
                __struct__: User,
                name: "Bob",
                scores: [10, 20],
                metadata: %{"role" => "admin"}
              }} =
               Lux.Python.eval("""
               {
                 '__class__': 'user',
                 'name': 'Bob',
                 'scores': [10, 20],
                 'metadata': {'role': 'admin'}
               }
               """)

      # List of structs
      assert {:ok,
              [
                %{__struct__: Item, id: 1},
                %{__struct__: Item, id: 2}
              ]} =
               Lux.Python.eval("""
               [
                 {'__class__': 'item', 'id': 1},
                 {'__class__': 'item', 'id': 2}
               ]
               """)

      # Nested structs
      assert {:ok,
              %{
                __struct__: Order,
                id: "123",
                customer: %{
                  __struct__: User,
                  name: "Charlie"
                },
                items: [
                  %{__struct__: Item, id: 1},
                  %{__struct__: Item, id: 2}
                ]
              }} =
               Lux.Python.eval("""
               {
                 '__class__': 'order',
                 'id': '123',
                 'customer': {
                   '__class__': 'user',
                   'name': 'Charlie'
                 },
                 'items': [
                   {'__class__': 'item', 'id': 1},
                   {'__class__': 'item', 'id': 2}
                 ]
               }
               """)
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

  describe "atom safety" do
    test "raises error for unsafe struct field names" do
      # Attempt to create a struct with an unsafe field name
      assert {:error, "UnsafeAtomError: Attempted to create unsafe atom: unsafe_field"} =
               Lux.Python.eval("""
               {
                 '__class__': 'user',
                 'name': 'Alice',
                 'unsafe_field': 'value'
               }
               """)
    end

    test "allows structs with only safe field names" do
      assert {:ok, %{__struct__: User, name: "Alice", role: "admin"}} =
               Lux.Python.eval("""
               {
                 '__class__': 'user',
                 'name': 'Alice',
                 'role': 'admin'
               }
               """)
    end

    test "handles nested structs with unsafe fields" do
      assert {:error, "UnsafeAtomError: Attempted to create unsafe atom: unsafe_nested"} =
               Lux.Python.eval("""
               {
                 '__class__': 'order',
                 'id': '123',
                 'customer': {
                   '__class__': 'user',
                   'name': 'Alice',
                   'unsafe_nested': 'value'
                 }
               }
               """)
    end

    test "allows nested structs with safe fields" do
      assert {:ok,
              %{
                __struct__: Order,
                id: "123",
                customer: %{
                  __struct__: User,
                  name: "Alice",
                  role: "admin"
                }
              }} =
               Lux.Python.eval("""
               {
                 '__class__': 'order',
                 'id': '123',
                 'customer': {
                   '__class__': 'user',
                   'name': 'Alice',
                   'role': 'admin'
                 }
               }
               """)
    end

    test "handles Web3 and crypto-related structs" do
      # Transaction struct
      assert {:ok,
              %{
                __struct__: Transaction,
                tx_hash: "0x123...",
                from_address: "0xabc...",
                to_address: "0xdef...",
                value: 1_000_000_000_000_000_000,
                gas_price: 20_000_000_000,
                gas_limit: 21000,
                nonce: 42,
                status: "confirmed"
              }} =
               Lux.Python.eval("""
               {
                 '__class__': 'transaction',
                 'tx_hash': '0x123...',
                 'from_address': '0xabc...',
                 'to_address': '0xdef...',
                 'value': 1000000000000000000,
                 'gas_price': 20000000000,
                 'gas_limit': 21000,
                 'nonce': 42,
                 'status': 'confirmed'
               }
               """)

      # NFT with metadata
      assert {:ok,
              %{
                __struct__: Nft,
                token_id: 123,
                token_uri: "ipfs://...",
                metadata: %{
                  "name" => "Cool NFT",
                  "description" => "A very cool NFT"
                },
                owner: "0xabc...",
                collection: %{
                  __struct__: Collection,
                  contract_address: "0xdef...",
                  name: "Cool Collection",
                  symbol: "COOL"
                }
              }} =
               Lux.Python.eval("""
               {
                 '__class__': 'nft',
                 'token_id': 123,
                 'token_uri': 'ipfs://...',
                 'metadata': {
                   'name': 'Cool NFT',
                   'description': 'A very cool NFT'
                 },
                 'owner': '0xabc...',
                 'collection': {
                   '__class__': 'collection',
                   'contract_address': '0xdef...',
                   'name': 'Cool Collection',
                   'symbol': 'COOL'
                 }
               }
               """)

      # DeFi pool state
      assert {:ok,
              %{
                __struct__: Pool,
                address: "0x789...",
                token_address: "0xabc...",
                liquidity: 1_000_000,
                apy: 12.5,
                total_supply: 1_000_000,
                reserves: [100_000, 200_000],
                stake: %{
                  __struct__: Stake,
                  amount: 1000,
                  rewards: 50,
                  apr: 10.5
                }
              }} =
               Lux.Python.eval("""
               {
                 '__class__': 'pool',
                 'address': '0x789...',
                 'token_address': '0xabc...',
                 'liquidity': 1000000,
                 'apy': 12.5,
                 'total_supply': 1000000,
                 'reserves': [100000, 200000],
                 'stake': {
                   '__class__': 'stake',
                   'amount': 1000,
                   'rewards': 50,
                   'apr': 10.5
                 }
               }
               """)
    end
  end
end

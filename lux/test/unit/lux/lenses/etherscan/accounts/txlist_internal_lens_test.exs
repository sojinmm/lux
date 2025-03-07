defmodule Lux.Lenses.Etherscan.TxListInternalLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TxListInternal

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    on_exit(fn ->
      # Clean up after tests
      Application.delete_env(:lux, :api_keys)
    end)

    :ok
  end

  describe "focus/1 with address parameter" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
        chainid: 1,
        startblock: 0,
        endblock: 2702578,
        page: 1,
        offset: 10,
        sort: "asc"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlistinternal"
        assert query["address"] == "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3"
        assert query["startblock"] == "0"
        assert query["endblock"] == "2702578"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample internal transactions
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "2702578",
              "timeStamp" => "1472278636",
              "hash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
              "from" => "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
              "to" => "0x9eab4b0fc468a7f5d46228bf5a76cb52370d068d",
              "value" => "50000000000000000",
              "contractAddress" => "",
              "input" => "",
              "type" => "call",
              "gas" => "2300",
              "gasUsed" => "0",
              "traceId" => "0",
              "isError" => "0",
              "errCode" => ""
            }
          ]
        })
      end)

      # Call the lens
      result = TxListInternal.focus(params)

      # Verify the result
      assert {:ok, %{result: [transaction]}} = result
      assert transaction["hash"] == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      assert transaction["from"] == "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3"
      assert transaction["value"] == "50000000000000000"
    end

    test "handles empty transaction list" do
      # Set up the test parameters
      params = %{
        address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty transaction list
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No internal transactions found"
        })
      end)

      # Call the lens
      result = TxListInternal.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No internal transactions found"}} = result
    end
  end

  describe "focus/1 with txhash parameter" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlistinternal"
        assert query["txhash"] == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample internal transactions
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "2702578",
              "timeStamp" => "1472278636",
              "hash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
              "from" => "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
              "to" => "0x9eab4b0fc468a7f5d46228bf5a76cb52370d068d",
              "value" => "50000000000000000",
              "contractAddress" => "",
              "input" => "",
              "type" => "call",
              "gas" => "2300",
              "gasUsed" => "0",
              "traceId" => "0",
              "isError" => "0",
              "errCode" => ""
            }
          ]
        })
      end)

      # Call the lens
      result = TxListInternal.focus(params)

      # Verify the result
      assert {:ok, %{result: [transaction]}} = result
      assert transaction["hash"] == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
    end
  end

  describe "focus/1 with block range parameters" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        startblock: 13481773,
        endblock: 13491773,
        page: 1,
        offset: 10,
        sort: "asc",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlistinternal"
        assert query["startblock"] == "13481773"
        assert query["endblock"] == "13491773"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample internal transactions
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "13481780",
              "timeStamp" => "1632218636",
              "hash" => "0x8a1a9989bda84f80143181a68bc137ecefa64d0d4ebde45dd94fc0cf49e70cb6",
              "from" => "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",
              "to" => "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f",
              "value" => "0",
              "contractAddress" => "",
              "input" => "",
              "type" => "call",
              "gas" => "2300",
              "gasUsed" => "0",
              "traceId" => "0",
              "isError" => "0",
              "errCode" => ""
            }
          ]
        })
      end)

      # Call the lens
      result = TxListInternal.focus(params)

      # Verify the result
      assert {:ok, %{result: [transaction]}} = result
      assert transaction["blockNumber"] == "13481780"
      assert transaction["hash"] == "0x8a1a9989bda84f80143181a68bc137ecefa64d0d4ebde45dd94fc0cf49e70cb6"
    end
  end

  describe "error handling" do
    test "handles error responses" do
      # Set up the test parameters
      params = %{
        address: "0xinvalid",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address format"
        })
      end)

      # Call the lens
      result = TxListInternal.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a Pro API key error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "This endpoint requires a Pro subscription"
        })
      end)

      # Call the lens
      result = TxListInternal.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly for address query" do
      # Set up the test parameters
      params = %{
        address: "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
        chainid: 1,
        startblock: 0,
        endblock: 2702578,
        page: 1,
        offset: 10,
        sort: "asc"
      }

      # Call the function
      result = TxListInternal.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "txlistinternal"
      assert result.address == "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3"
      assert result.chainid == 1
      assert result.startblock == 0
      assert result.endblock == 2702578
      assert result.page == 1
      assert result.offset == 10
      assert result.sort == "asc"
    end

    test "prepares parameters correctly for txhash query" do
      # Set up the test parameters
      params = %{
        txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
        chainid: 1
      }

      # Call the function
      result = TxListInternal.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "txlistinternal"
      assert result.txhash == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      assert result.chainid == 1
    end

    test "prepares parameters correctly for block range query" do
      # Set up the test parameters
      params = %{
        startblock: 13481773,
        endblock: 13491773,
        page: 1,
        offset: 10,
        sort: "asc",
        chainid: 1
      }

      # Call the function
      result = TxListInternal.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "txlistinternal"
      assert result.startblock == 13481773
      assert result.endblock == 13491773
      assert result.page == 1
      assert result.offset == 10
      assert result.sort == "asc"
      assert result.chainid == 1
    end

    test "raises error for invalid parameters" do
      # Set up invalid parameters (missing required fields)
      params = %{
        chainid: 1,
        page: 1,
        offset: 10,
        sort: "asc"
      }

      # Expect an error to be raised
      assert_raise ArgumentError, fn ->
        TxListInternal.before_focus(params)
      end
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "blockNumber" => "2702578",
            "timeStamp" => "1472278636",
            "hash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
            "from" => "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
            "to" => "0x9eab4b0fc468a7f5d46228bf5a76cb52370d068d",
            "value" => "50000000000000000",
            "contractAddress" => "",
            "input" => "",
            "type" => "call",
            "gas" => "2300",
            "gasUsed" => "0",
            "traceId" => "0",
            "isError" => "0",
            "errCode" => ""
          }
        ]
      }

      # Call the function
      result = TxListInternal.after_focus(response)

      # Verify the result
      assert {:ok, %{result: [transaction]}} = result
      assert transaction["hash"] == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = TxListInternal.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

defmodule Lux.Lenses.Etherscan.TokenErc1155TxLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TokenErc1155Tx

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
        address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
        chainid: 1,
        startblock: 0,
        endblock: 27025780,
        page: 1,
        offset: 100,
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
        assert query["action"] == "token1155tx"
        assert query["address"] == "0x83f564d180b58ad9a02a449105568189ee7de8cb"
        assert query["startblock"] == "0"
        assert query["endblock"] == "27025780"
        assert query["page"] == "1"
        assert query["offset"] == "100"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample ERC-1155 transfers
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "12345678",
              "timeStamp" => "1622222222",
              "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
              "nonce" => "123",
              "blockHash" => "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "from" => "0x83f564d180b58ad9a02a449105568189ee7de8cb",
              "contractAddress" => "0x76be3b62873462d2142405439777e971754e8e77",
              "to" => "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
              "tokenID" => "123456",
              "tokenName" => "OpenSea Shared Storefront",
              "tokenSymbol" => "OPENSTORE",
              "tokenDecimal" => "0",
              "transactionIndex" => "123",
              "gas" => "100000",
              "gasPrice" => "50000000000",
              "gasUsed" => "80000",
              "cumulativeGasUsed" => "1000000",
              "input" => "0x",
              "confirmations" => "1000",
              "value" => "1"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenErc1155Tx.focus(params)

      # Verify the result
      assert {:ok, %{result: [transfer]}} = result
      assert transfer["hash"] == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
      assert transfer["from"] == "0x83f564d180b58ad9a02a449105568189ee7de8cb"
      assert transfer["contractAddress"] == "0x76be3b62873462d2142405439777e971754e8e77"
      assert transfer["tokenID"] == "123456"
      assert transfer["tokenName"] == "OpenSea Shared Storefront"
      assert transfer["value"] == "1"
    end

    test "handles empty transfer list" do
      # Set up the test parameters
      params = %{
        address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty transfer list
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No ERC-1155 transfers found"
        })
      end)

      # Call the lens
      result = TokenErc1155Tx.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No ERC-1155 transfers found"}} = result
    end
  end

  describe "focus/1 with contractaddress parameter" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x76be3b62873462d2142405439777e971754e8e77",
        chainid: 1,
        page: 1,
        offset: 10
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "token1155tx"
        assert query["contractaddress"] == "0x76be3b62873462d2142405439777e971754e8e77"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample ERC-1155 transfers
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "12345678",
              "timeStamp" => "1622222222",
              "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
              "nonce" => "123",
              "blockHash" => "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "from" => "0x83f564d180b58ad9a02a449105568189ee7de8cb",
              "contractAddress" => "0x76be3b62873462d2142405439777e971754e8e77",
              "to" => "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
              "tokenID" => "123456",
              "tokenName" => "OpenSea Shared Storefront",
              "tokenSymbol" => "OPENSTORE",
              "tokenDecimal" => "0",
              "transactionIndex" => "123",
              "gas" => "100000",
              "gasPrice" => "50000000000",
              "gasUsed" => "80000",
              "cumulativeGasUsed" => "1000000",
              "input" => "0x",
              "confirmations" => "1000",
              "value" => "1"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenErc1155Tx.focus(params)

      # Verify the result
      assert {:ok, %{result: [transfer]}} = result
      assert transfer["contractAddress"] == "0x76be3b62873462d2142405439777e971754e8e77"
      assert transfer["tokenName"] == "OpenSea Shared Storefront"
      assert transfer["tokenID"] == "123456"
    end
  end

  describe "focus/1 with both address and contractaddress parameters" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
        contractaddress: "0x76be3b62873462d2142405439777e971754e8e77",
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
        assert query["action"] == "token1155tx"
        assert query["address"] == "0x83f564d180b58ad9a02a449105568189ee7de8cb"
        assert query["contractaddress"] == "0x76be3b62873462d2142405439777e971754e8e77"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample ERC-1155 transfers
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "12345678",
              "timeStamp" => "1622222222",
              "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
              "nonce" => "123",
              "blockHash" => "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "from" => "0x83f564d180b58ad9a02a449105568189ee7de8cb",
              "contractAddress" => "0x76be3b62873462d2142405439777e971754e8e77",
              "to" => "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
              "tokenID" => "123456",
              "tokenName" => "OpenSea Shared Storefront",
              "tokenSymbol" => "OPENSTORE",
              "tokenDecimal" => "0",
              "transactionIndex" => "123",
              "gas" => "100000",
              "gasPrice" => "50000000000",
              "gasUsed" => "80000",
              "cumulativeGasUsed" => "1000000",
              "input" => "0x",
              "confirmations" => "1000",
              "value" => "1"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenErc1155Tx.focus(params)

      # Verify the result
      assert {:ok, %{result: [transfer]}} = result
      assert transfer["from"] == "0x83f564d180b58ad9a02a449105568189ee7de8cb"
      assert transfer["contractAddress"] == "0x76be3b62873462d2142405439777e971754e8e77"
      assert transfer["tokenID"] == "123456"
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
      result = TokenErc1155Tx.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
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
      result = TokenErc1155Tx.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly for address query" do
      # Set up the test parameters
      params = %{
        address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
        chainid: 1,
        startblock: 0,
        endblock: 27025780,
        page: 1,
        offset: 100,
        sort: "asc"
      }

      # Call the function
      result = TokenErc1155Tx.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "token1155tx"
      assert result.address == "0x83f564d180b58ad9a02a449105568189ee7de8cb"
      assert result.chainid == 1
      assert result.startblock == 0
      assert result.endblock == 27025780
      assert result.page == 1
      assert result.offset == 100
      assert result.sort == "asc"
    end

    test "prepares parameters correctly for contractaddress query" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x76be3b62873462d2142405439777e971754e8e77",
        chainid: 1
      }

      # Call the function
      result = TokenErc1155Tx.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "token1155tx"
      assert result.contractaddress == "0x76be3b62873462d2142405439777e971754e8e77"
      assert result.chainid == 1
    end

    test "prepares parameters correctly for combined query" do
      # Set up the test parameters
      params = %{
        address: "0x83f564d180b58ad9a02a449105568189ee7de8cb",
        contractaddress: "0x76be3b62873462d2142405439777e971754e8e77",
        chainid: 1
      }

      # Call the function
      result = TokenErc1155Tx.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "token1155tx"
      assert result.address == "0x83f564d180b58ad9a02a449105568189ee7de8cb"
      assert result.contractaddress == "0x76be3b62873462d2142405439777e971754e8e77"
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
        TokenErc1155Tx.before_focus(params)
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
            "blockNumber" => "12345678",
            "timeStamp" => "1622222222",
            "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            "from" => "0x83f564d180b58ad9a02a449105568189ee7de8cb",
            "contractAddress" => "0x76be3b62873462d2142405439777e971754e8e77",
            "to" => "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
            "tokenID" => "123456",
            "tokenName" => "OpenSea Shared Storefront",
            "tokenSymbol" => "OPENSTORE",
            "tokenDecimal" => "0",
            "value" => "1"
          }
        ]
      }

      # Call the function
      result = TokenErc1155Tx.after_focus(response)

      # Verify the result
      assert {:ok, %{result: [transfer]}} = result
      assert transfer["hash"] == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
      assert transfer["tokenID"] == "123456"
      assert transfer["tokenName"] == "OpenSea Shared Storefront"
      assert transfer["value"] == "1"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = TokenErc1155Tx.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

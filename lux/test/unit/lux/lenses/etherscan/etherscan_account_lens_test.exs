defmodule Lux.Lenses.EtherscanAccountLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.EtherscanAccountLens

  @test_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @test_contract_address "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984" # UNI token
  @test_tx_hash "0x4d74a6fc84d57f18b8e1dfa07ee517c4feb296d16a8353ee41adc03669982028"

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "lens configuration" do
    test "has correct lens configuration" do
      lens = EtherscanAccountLens.view()

      assert lens.name == "Etherscan Account API"
      assert lens.description == "Fetches account data from the Etherscan API"
      assert lens.method == :get
      assert lens.url == "https://api.etherscan.io/v2/api"
      assert {"content-type", "application/json"} in lens.headers
      assert lens.auth.type == :custom
      assert is_function(lens.auth.auth_function)
    end

    test "schema has required fields" do
      lens = EtherscanAccountLens.view()

      assert lens.schema.type == :object
      assert lens.schema.required == ["action", "address"]
      assert Map.has_key?(lens.schema.properties, :action)
      assert Map.has_key?(lens.schema.properties, :address)
      assert Map.has_key?(lens.schema.properties, :network)
    end
  end

  describe "get_chain_id/1" do
    test "returns correct chain ID for ethereum" do
      assert EtherscanAccountLens.get_chain_id("ethereum") == "1"
    end

    test "returns correct chain ID for polygon" do
      assert EtherscanAccountLens.get_chain_id("polygon") == "137"
    end

    test "returns correct chain ID for base" do
      assert EtherscanAccountLens.get_chain_id("base") == "8453"
    end

    test "defaults to ethereum chain ID for unknown networks" do
      assert EtherscanAccountLens.get_chain_id("unknown_network") == "1"
    end
  end

  describe "add_api_key/1" do
    test "adds API key to params" do
      lens = %{params: %{action: "balance", address: @test_address}}

      # Set up the test environment to return a test API key
      Application.put_env(:lux, :api_keys, [etherscan: "TEST_API_KEY"])

      updated_lens = EtherscanAccountLens.add_api_key(lens)
      assert updated_lens.params.apikey == "TEST_API_KEY"
    end
  end

  describe "before_focus/1" do
    test "adds module parameter" do
      params = %{action: "balance", address: @test_address}

      updated_params = EtherscanAccountLens.before_focus(params)
      assert updated_params.module == "account"
    end

    test "converts addresses list to comma-separated string" do
      params = %{
        action: "balancemulti",
        addresses: [@test_address, "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"]
      }

      updated_params = EtherscanAccountLens.before_focus(params)
      assert updated_params.address == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045,0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      refute Map.has_key?(updated_params, :addresses)
    end

    test "adds chain ID based on network" do
      params = %{action: "balance", address: @test_address, network: "polygon"}

      updated_params = EtherscanAccountLens.before_focus(params)
      assert updated_params.chainid == "137"
    end

    test "removes network parameter" do
      params = %{action: "balance", address: @test_address, network: "ethereum"}

      updated_params = EtherscanAccountLens.before_focus(params)
      refute Map.has_key?(updated_params, :network)
    end
  end

  describe "after_focus/1" do
    test "handles successful response" do
      response = %{"status" => "1", "message" => "OK", "result" => "123456789"}

      assert EtherscanAccountLens.after_focus(response) == {:ok, %{result: "123456789"}}
    end

    test "handles error response" do
      response = %{"status" => "0", "message" => "Error", "result" => "Invalid address"}

      assert EtherscanAccountLens.after_focus(response) == {:error, %{message: "Error", result: "Invalid address"}}
    end

    test "handles error object" do
      response = %{"error" => "API key invalid"}

      assert EtherscanAccountLens.after_focus(response) == {:error, "API key invalid"}
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}

      assert {:error, message} = EtherscanAccountLens.after_focus(response)
      assert String.contains?(message, "Unexpected response format")
    end
  end

  describe "validate_eth_address/1" do
    test "validates correct Ethereum address" do
      assert EtherscanAccountLens.validate_eth_address(@test_address) == {:ok, @test_address}
    end

    test "rejects invalid Ethereum address" do
      assert {:error, message} = EtherscanAccountLens.validate_eth_address("invalid_address")
      assert String.contains?(message, "Invalid Ethereum address format")
    end
  end

  describe "validate_tx_hash/1" do
    test "validates correct transaction hash" do
      assert EtherscanAccountLens.validate_tx_hash(@test_tx_hash) == {:ok, @test_tx_hash}
    end

    test "rejects invalid transaction hash" do
      assert {:error, message} = EtherscanAccountLens.validate_tx_hash("invalid_hash")
      assert String.contains?(message, "Invalid transaction hash format")
    end
  end

  describe "validate_block/1" do
    test "validates block number as string" do
      assert EtherscanAccountLens.validate_block("12345") == {:ok, "12345"}
    end

    test "validates block number as integer" do
      assert EtherscanAccountLens.validate_block(12345) == {:ok, "12345"}
    end

    test "validates block tags" do
      assert EtherscanAccountLens.validate_block("latest") == {:ok, "latest"}
      assert EtherscanAccountLens.validate_block("pending") == {:ok, "pending"}
      assert EtherscanAccountLens.validate_block("earliest") == {:ok, "earliest"}
    end

    test "rejects invalid block format" do
      assert {:error, message} = EtherscanAccountLens.validate_block("invalid_block")
      assert String.contains?(message, "Invalid block format")

      assert {:error, message} = EtherscanAccountLens.validate_block(-1)
      assert String.contains?(message, "Invalid block format")
    end
  end

  # Note: The "focus/1 integration" tests have been removed as they touch real-life API calls
end

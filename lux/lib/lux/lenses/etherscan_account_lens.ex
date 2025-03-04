defmodule Lux.Lenses.EtherscanAccountLens do
  @moduledoc """
  Lens for fetching account data from the Etherscan API.

  This lens provides access to various account-related endpoints for Ethereum addresses,
  including balance, token balances, transaction lists, and historical balances.

  ## Examples

  ```elixir
  # Get ETH balance for an address
  Lux.Lenses.EtherscanAccountLens.focus(%{
    action: "balance",
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
  })

  # Get token balance for an address
  Lux.Lenses.EtherscanAccountLens.focus(%{
    action: "tokenbalance",
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055"
  })

  # Get normal transactions for an address on Polygon
  Lux.Lenses.EtherscanAccountLens.focus(%{
    action: "txlist",
    address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    startblock: 0,
    endblock: 99999999,
    network: "polygon"
  })
  ```
  """

  use Lux.Lens,
    name: "Etherscan Account API",
    description: "Fetches account data from the Etherscan API",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        network: %{
          type: :string,
          description: "Blockchain network to query",
          default: "ethereum",
          enum: [
            "ethereum",
            "polygon",
            "optimism",
            "arbitrum",
            "bsc",
            "base",
            "avalanche"
          ]
        },
        action: %{
          type: :string,
          description: "The Etherscan API action to perform",
          enum: [
            "balance",
            "balancemulti",
            "balancehistory",
            "tokenbalance",
            "txlist",
            "txlistinternal",
            "tokentx",
            "tokennfttx",
            "token1155tx",
            "getminedblocks",
            "txsBeaconWithdrawal"
          ]
        },
        address: %{
          type: :string,
          description: "Ethereum address to query",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        addresses: %{
          type: :array,
          description: "List of Ethereum addresses (for balancemulti)",
          items: %{
            type: :string,
            pattern: "^0x[a-fA-F0-9]{40}$"
          },
          maxItems: 20
        },
        contractaddress: %{
          type: :string,
          description: "Token contract address (for token operations)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Starting block number",
          minimum: 0
        },
        endblock: %{
          type: :integer,
          description: "Ending block number",
          minimum: 0
        },
        blockno: %{
          type: :integer,
          description: "Block number for historical balance",
          minimum: 0
        },
        txhash: %{
          type: :string,
          description: "Transaction hash",
          pattern: "^0x[a-fA-F0-9]{64}$"
        },
        page: %{
          type: :integer,
          description: "Page number for pagination",
          minimum: 1,
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of records per page",
          minimum: 1,
          maximum: 10000,
          default: 10
        },
        sort: %{
          type: :string,
          description: "Sorting preference",
          enum: ["asc", "desc"],
          default: "asc"
        },
        tag: %{
          type: :string,
          description: "Block parameter",
          enum: ["latest", "pending", "earliest"],
          default: "latest"
        },
        blocktype: %{
          type: :string,
          description: "Type of blocks to fetch",
          enum: ["blocks", "uncles"],
          default: "blocks"
        }
      },
      required: ["action", "address"]
    }

  @doc """
  Adds the Etherscan API key to the lens parameters.
  """
  def add_api_key(lens) do
    Map.update!(lens, :params, fn params ->
      Map.put(params, :apikey, Lux.Config.etherscan_api_key())
    end)
  end

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module to "account" for all account-related endpoints
    params = Map.put(params, :module, "account")

    # Handle addresses list for balancemulti
    params = if Map.has_key?(params, :addresses) do
      addresses = params.addresses |> Enum.join(",")
      params
      |> Map.put(:address, addresses)
      |> Map.delete(:addresses)
    else
      params
    end

    # Add chain ID based on network
    network = Map.get(params, :network, "ethereum")
    chain_id = get_chain_id(network)
    params = Map.put(params, :chainid, chain_id)

    # Remove network from params as it's not needed in the API call
    Map.delete(params, :network)
  end

  @doc """
  Gets the chain ID for a given network.
  """
  def get_chain_id(network) do
    case network do
      "ethereum" -> "1"
      "polygon" -> "137"
      "optimism" -> "10"
      "arbitrum" -> "42161"
      "bsc" -> "56"
      "base" -> "8453"
      "avalanche" -> "43114"
      _ -> "1" # Default to Ethereum mainnet
    end
  end

  @doc """
  Transforms the API response into a more usable format.

  ## Examples

      iex> after_focus(%{"status" => "1", "message" => "OK", "result" => "123456789"})
      {:ok, %{result: "123456789"}}

      iex> after_focus(%{"status" => "0", "message" => "Error", "result" => "Invalid address"})
      {:error, %{message: "Error", result: "Invalid address"}}
  """
  @impl true
  def after_focus(%{"status" => "1", "message" => "OK", "result" => result}) do
    {:ok, %{result: result}}
  end

  @impl true
  def after_focus(%{"status" => "0", "message" => message, "result" => result}) do
    {:error, %{message: message, result: result}}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  @doc """
  Validates an Ethereum address format.
  """
  def validate_eth_address(address) when is_binary(address) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      {:ok, address}
    else
      {:error, "Invalid Ethereum address format: #{address}"}
    end
  end

  @doc """
  Validates a transaction hash format.
  """
  def validate_tx_hash(hash) when is_binary(hash) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{64}$/, hash) do
      {:ok, hash}
    else
      {:error, "Invalid transaction hash format: #{hash}"}
    end
  end

  @doc """
  Validates a block number or block tag.
  """
  def validate_block(block) when is_binary(block) do
    case block do
      "latest" -> {:ok, block}
      "pending" -> {:ok, block}
      "earliest" -> {:ok, block}
      _ ->
        if Regex.match?(~r/^[0-9]+$/, block) do
          {:ok, block}
        else
          {:error, "Invalid block format: #{block}"}
        end
    end
  end

  def validate_block(block) when is_integer(block) and block >= 0 do
    {:ok, Integer.to_string(block)}
  end

  def validate_block(block) do
    {:error, "Invalid block format: #{inspect(block)}"}
  end
end

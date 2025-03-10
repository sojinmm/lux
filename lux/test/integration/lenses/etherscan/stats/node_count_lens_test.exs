defmodule Lux.Integration.Etherscan.NodeCountLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.NodeCount
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  test "can fetch node count" do
    assert {:ok, %{result: node_count, node_count: node_count}} =
             RateLimitedAPI.call_standard(NodeCount, :focus, [%{
               chainid: 1
             }])

    # Verify the structure of the response
    assert is_map(node_count)
    assert Map.has_key?(node_count, :total)
    
    # Convert total to integer if it's a string
    total = case node_count.total do
      total when is_binary(total) -> 
        case Integer.parse(total) do
          {int, _} -> int
          :error -> 0
        end
      total when is_integer(total) -> total
      _ -> 0
    end
    
    # Total node count should be a positive number
    assert total > 0
  end
end

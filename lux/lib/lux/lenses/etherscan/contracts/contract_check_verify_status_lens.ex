defmodule Lux.Lenses.Etherscan.ContractCheckVerifyStatus do
  @moduledoc """
  Lens for checking the status of a contract verification request from the Etherscan API.

  ## Examples

  ```elixir
  # Check the status of a contract verification request
  Lux.Lenses.Etherscan.ContractCheckVerifyStatus.focus(%{
    guid: "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
  })

  # Check the status of a contract verification request on a specific chain
  Lux.Lenses.Etherscan.ContractCheckVerifyStatus.focus(%{
    guid: "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan Contract Verification Status API",
    description: "Checks the status of a contract verification request",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Chain ID to query (e.g., 1 for Ethereum, 137 for Polygon)",
          default: 1
        },
        guid: %{
          type: :string,
          description: "The unique GUID received from the verification request"
        }
      },
      required: ["guid"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "contract")
    |> Map.put(:action, "checkverifystatus")
  end

  @doc """
  Transforms the API response into a more usable format.
  For contract verification status, we need to interpret the result string.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_binary(result) ->
        # Determine the status based on the result string
        status = cond do
          String.contains?(result, "Pending") -> "Pending"
          String.contains?(result, "Fail") -> "Failed"
          String.contains?(result, "Pass") -> "Success"
          true -> "Unknown"
        end

        # Return a structured response with the status and message
        {:ok, %{result: %{status: status, message: result}}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end

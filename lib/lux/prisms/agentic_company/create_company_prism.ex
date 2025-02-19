defmodule Lux.Prisms.AgenticCompany.CreateCompanyPrism do
  @moduledoc """
  A prism that creates a new company using the AgenticCompanyFactory contract.

  ## Example

      iex> Lux.Prisms.AgenticCompany.CreateCompanyPrism.run(%{
      ...>   company_name: "Some Test Company",
      ...>   agent_token: "0x0000000000000000000000000000000000000000"  # zero address for no token
      ...> })
      {:ok, %{
        company_address: "0x5678..."  # The address of the newly created company contract
      }}
  """

  use Lux.Prism,
    name: "Create Company",
    description: "Creates a new company using the AgenticCompanyFactory contract",
    input_schema: %{
      type: :object,
      properties: %{
        company_name: %{
          type: :string,
          description: "Name of the company to create"
        },
        agent_token: %{
          type: :string,
          description: "Address of the agent token to use (zero address if none)"
        }
      },
      required: ["company_name", "agent_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        company_address: %{
          type: :string,
          description: "Address of the newly created company contract"
        }
      },
      required: ["company_address"]
    }

  alias Lux.Web3.Contracts.AgenticCompanyFactory

  require Logger

  def handler(%{company_name: company_name, agent_token: agent_token}, _ctx) do
    Logger.info("Creating company with name: #{company_name} and agent token: #{agent_token}")

    with {:ok, tx_hash} <- create_company_transaction(company_name, agent_token),
         task <- Task.async(fn -> wait_for_company_created_event(tx_hash) end),
         {:ok, company_address} <- Task.await(task, :timer.minutes(5)) do
      {:ok, %{company_address: company_address}}
    else
      {:error, reason} ->
        Logger.error("Company creation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_company_transaction(company_name, agent_token) do
    company_name
    |> AgenticCompanyFactory.create_company(agent_token)
    |> Ethers.send_transaction(from: Lux.Config.wallet_address())
  end

  defp wait_for_company_created_event(tx_hash) do
    case Ethers.get_transaction_receipt(tx_hash) do
      {:ok, receipt} -> process_receipt(receipt, tx_hash)
      {:error, :transaction_receipt_not_found} ->
        Process.sleep(2000)
        wait_for_company_created_event(tx_hash)
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_receipt(receipt, tx_hash) do
    event_filter =
      AgenticCompanyFactory.EventFilters.company_created(nil, Lux.Config.wallet_address())

    receipt["logs"]
    |> Enum.find(&matching_event?(&1, event_filter))
    |> handle_event_log(tx_hash)
  end

  defp matching_event?(log, event_filter) do
    List.first(log["topics"]) == List.first(event_filter.topics)
  end

  defp handle_event_log(nil, tx_hash) do
    Process.sleep(2000)
    wait_for_company_created_event(tx_hash)
  end

  defp handle_event_log(log, _tx_hash) do
    company_address =
      log["topics"]
      |> Enum.at(1)
      |> String.slice(-40..-1)
      |> then(&"0x#{&1}")

    Logger.info("Found company address in event: #{company_address}")
    {:ok, company_address}
  end
end

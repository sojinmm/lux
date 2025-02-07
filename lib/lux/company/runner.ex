defmodule Lux.Company.Runner do
  @moduledoc """
  Handles the execution of plans within a company.

  The runner is responsible for:
  - Validating plan inputs
  - Coordinating between agents to execute plan steps
  - Tracking plan progress
  - Delivering results
  """

  use GenServer

  def start_link({company, opts}) do
    GenServer.start_link(__MODULE__, {company, opts}, name: name_for(company))
  end

  @impl true
  def init({company, _opts}) do
    {:ok, %{company: company}}
  end

  @impl true
  def handle_call({:run_plan, plan_name, _params}, _from, state) do
    case Map.fetch(state.company.plans, plan_name) do
      {:ok, _plan} ->
        # TODO: Implement plan execution logic
        {:reply, {:ok, "Plan execution started"}, state}

      :error ->
        {:reply, {:error, "Plan not found"}, state}
    end
  end

  defp name_for(company) do
    Module.concat(company, "Runner")
  end
end

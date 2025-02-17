defmodule Lux.Company.Hub.Local do
  @moduledoc """
  A local memory implementation of the Company Hub behavior.
  Uses an ETS table to store company registrations.
  """

  @behaviour Lux.Company.Hub

  use GenServer

  alias Lux.Company
  alias Lux.Company.Hub

  require Logger

  # Client API

  @impl Hub
  def register_company(company, hub) when is_atom(company) do
    # For module registration, call __company__ to get the struct
    company_struct = company.__company__()
    # Ensure it's a proper Company struct with module field set
    company_struct =
      struct!(
        Company,
        Map.merge(Map.from_struct(company_struct), %{
          module: company,
          id: generate_company_id()
        })
      )

    GenServer.call(hub, {:register_company, company_struct.id, company_struct})
  end

  def register_company(%Company{} = company_struct, hub) do
    # For struct registration, use the existing ID or generate a new one
    company_id = company_struct.id || generate_company_id()
    company_struct = %{company_struct | id: company_id}
    GenServer.call(hub, {:register_company, company_id, company_struct})
  end

  @impl Hub
  def get_company(company_id, hub) do
    GenServer.call(hub, {:get_company, company_id})
  end

  @impl Hub
  def list_companies(hub) do
    GenServer.call(hub, :list_companies)
  end

  @impl Hub
  def search_companies(query, hub, opts \\ []) do
    GenServer.call(hub, {:search_companies, query, opts})
  end

  @impl Hub
  def deregister_company(company_id, hub) do
    GenServer.call(hub, {:deregister_company, company_id})
  end

  # Server API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    table_name = Keyword.fetch!(opts, :table_name)
    GenServer.start_link(__MODULE__, table_name, name: name)
  end

  @impl GenServer
  def init(table_name) do
    Logger.info("Starting local company hub with table: #{table_name}")
    table = :ets.new(table_name, [:set, :protected, :named_table])
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:register_company, company_id, %Company{} = company}, _from, state) do
    Logger.info("Registering company: #{company.name} with ID: #{company_id}")
    true = :ets.insert(state.table, {company_id, company})
    {:reply, {:ok, company_id}, state}
  end

  def handle_call({:get_company, company_id}, _from, state) do
    case :ets.lookup(state.table, company_id) do
      [{^company_id, %Company{} = company}] ->
        {:reply, {:ok, company}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list_companies, _from, state) do
    companies =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, %Company{} = company} -> company end)

    {:reply, {:ok, companies}, state}
  end

  def handle_call({:search_companies, query, opts}, _from, state) do
    name_filter = Keyword.get(opts, :name)

    results =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, %Company{} = company} -> company end)
      |> filter_companies(query, name_filter)

    {:reply, {:ok, results}, state}
  end

  def handle_call({:deregister_company, company_id}, _from, state) do
    case :ets.lookup(state.table, company_id) do
      [{^company_id, %Company{}}] ->
        true = :ets.delete(state.table, company_id)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  # Private Functions

  defp generate_company_id do
    Lux.UUID.generate()
  end

  defp filter_companies(companies, query, name_filter) do
    Enum.filter(companies, fn %Company{} = company ->
      name_matches =
        case name_filter do
          nil -> true
          name -> String.downcase(company.name) =~ String.downcase(name)
        end

      query_matches =
        String.downcase(company.name) =~ String.downcase(query) or
          String.downcase(company.mission) =~ String.downcase(query)

      name_matches and query_matches
    end)
  end
end

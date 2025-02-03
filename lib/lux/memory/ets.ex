defmodule Lux.Memory.ETS do
  @moduledoc """
  ETS-based memory backend for Lux.
  Uses ordered_set for efficient chronological storage and retrieval.
  Keys are {timestamp, unique_id} tuples to ensure proper ordering and no collisions.
  """

  @behaviour Lux.Memory

  @registry_table :lux_memory_registry

  @impl true
  def initialize(opts) do
    # Ensure registry exists
    @registry_table
    |> :ets.whereis()
    |> case do
      :undefined -> :ets.new(@registry_table, [:set, :public, :named_table])
      _table_id -> :ok
    end

    # Create the main table
    main_table =
      case opts[:name] do
        nil -> :ets.new(__MODULE__, [:ordered_set, :public])
        name -> :ets.new(name, [:ordered_set, :public, :named_table])
      end

    # Create the counter table with a unique reference
    counter_table = :ets.new(:counter, [:set, :public])
    :ets.insert(counter_table, {:counter, 0})

    # Store both references and backend module in registry
    memory_ref = opts[:name] || main_table
    backend = opts[:backend] || __MODULE__
    true = :ets.insert(@registry_table, {memory_ref, {main_table, counter_table, backend}})

    {:ok, memory_ref}
  end

  @impl true
  def add(memory_ref, content, type \\ :observation, metadata \\ %{}) do
    {main_table, counter_table} = get_tables(memory_ref)

    timestamp = Map.get(metadata, :timestamp, System.system_time(:second))
    # Get and increment the counter atomically
    [{:counter, counter}] = :ets.lookup(counter_table, :counter)
    :ets.update_counter(counter_table, :counter, {2, 1})

    entry = %{
      id: counter,
      content: content,
      type: type,
      timestamp: timestamp,
      metadata: metadata
    }

    # Use {timestamp, counter} as the key for strict ordering with uniqueness
    true = :ets.insert(main_table, {{timestamp, counter}, entry})
    {:ok, entry}
  end

  @impl true
  def recent(memory_ref, n) do
    {main_table, _counter_table} = get_tables(memory_ref)

    case :ets.select_reverse(
           main_table,
           [
             {
               # Pattern: {{timestamp, counter}, entry}
               {{:"$1", :"$2"}, :"$3"},
               # No conditions
               [],
               # Return just the entry
               [:"$3"]
             }
           ],
           n
         ) do
      :"$end_of_table" -> {:ok, []}
      {memories, _continuation} when is_list(memories) -> {:ok, memories}
    end
  end

  @impl true
  def window(memory_ref, start_time, end_time) do
    {main_table, _counter_table} = get_tables(memory_ref)
    start_ts = DateTime.to_unix(start_time)
    end_ts = DateTime.to_unix(end_time)

    memories =
      :ets.select(main_table, [
        {
          # Pattern: {{timestamp, _counter}, entry}
          {{:"$1", :_}, :"$2"},
          [{:>=, :"$1", start_ts}, {:"=<", :"$1", end_ts}],
          [:"$2"]
        }
      ])

    {:ok, memories}
  end

  @impl true
  def search(memory_ref, query) do
    {main_table, _counter_table} = get_tables(memory_ref)
    pattern = String.downcase(query)

    # Get all entries and filter in Elixir
    memories =
      main_table
      |> :ets.select([
        # Match any key and capture the entry
        {
          {:_, :"$1"},
          # No conditions in match spec
          [],
          # Return the entry
          [:"$1"]
        }
      ])
      |> Enum.filter(fn entry ->
        entry.content
        |> String.downcase()
        |> String.contains?(pattern)
      end)

    {:ok, memories}
  end

  # Private helpers

  defp get_tables(memory_ref) do
    case :ets.lookup(@registry_table, memory_ref) do
      [{^memory_ref, {main_table, counter_table, _backend}}] -> {main_table, counter_table}
      [] -> raise "Memory reference #{inspect(memory_ref)} not found"
    end
  end
end

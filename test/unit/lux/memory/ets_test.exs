defmodule Lux.Memory.ETSTest do
  use UnitCase, async: true

  alias Lux.Memory.ETS

  describe "initialization" do
    test "creates unnamed table" do
      assert {:ok, memory_ref} = ETS.initialize([])
      assert is_reference(memory_ref)

      # Verify tables exist in registry
      [{^memory_ref, {main_table, counter_table, _backend}}] =
        :ets.lookup(:lux_memory_registry, memory_ref)

      assert :ordered_set == :ets.info(main_table, :type)
      assert :set == :ets.info(counter_table, :type)
      assert :public == :ets.info(main_table, :protection)
    end

    test "creates named table" do
      name = :"test_memory_#{:erlang.unique_integer()}"
      assert {:ok, ^name} = ETS.initialize(name: name)

      # Verify tables exist in registry
      [{^name, {main_table, counter_table, _backend}}] = :ets.lookup(:lux_memory_registry, name)
      assert :ordered_set == :ets.info(main_table, :type)
      assert :set == :ets.info(counter_table, :type)
      assert :public == :ets.info(main_table, :protection)
    end
  end

  describe "adding entries" do
    setup do
      {:ok, memory_ref} = ETS.initialize([])
      %{memory_ref: memory_ref}
    end

    test "adds entry and retrieves it", %{memory_ref: memory_ref} do
      content = "test content"
      type = :observation
      timestamp = System.system_time(:second)
      metadata = %{timestamp: timestamp}

      {:ok, entry} = ETS.add(memory_ref, content, type, metadata)
      # First entry should have ID 0
      assert entry.id == 0

      [{^memory_ref, {main_table, _counter, _backend}}] =
        :ets.lookup(:lux_memory_registry, memory_ref)

      assert [{{^timestamp, 0}, ^entry}] = :ets.tab2list(main_table)
    end

    test "maintains chronological order", %{memory_ref: memory_ref} do
      # Add entries with different timestamps
      _entries =
        for i <- 1..3 do
          timestamp = System.system_time(:second) + i

          {:ok, entry} =
            ETS.add(memory_ref, "content #{i}", :observation, %{timestamp: timestamp})

          entry
        end

      [{^memory_ref, {main_table, _counter, _backend}}] =
        :ets.lookup(:lux_memory_registry, memory_ref)

      stored_entries = :ets.tab2list(main_table)
      assert length(stored_entries) == 3

      # Verify timestamp ordering
      timestamps = Enum.map(stored_entries, fn {{ts, _id}, _entry} -> ts end)
      assert timestamps == Enum.sort(timestamps)
    end

    test "generates unique sequential IDs", %{memory_ref: memory_ref} do
      entries =
        for i <- 1..3 do
          {:ok, entry} = ETS.add(memory_ref, "content #{i}", :observation, %{})
          entry
        end

      ids = Enum.map(entries, & &1.id)
      assert ids == Enum.sort(ids)
      assert ids == [0, 1, 2]
    end
  end

  describe "retrieving recent entries" do
    setup do
      {:ok, memory_ref} = ETS.initialize([])

      entries =
        for i <- 1..5 do
          timestamp = System.system_time(:second) + i

          {:ok, entry} =
            ETS.add(memory_ref, "content #{i}", :observation, %{timestamp: timestamp})

          entry
        end

      %{memory_ref: memory_ref, entries: entries}
    end

    test "retrieves last n entries in reverse chronological order", %{
      memory_ref: memory_ref,
      entries: entries
    } do
      assert {:ok, recent} = ETS.recent(memory_ref, 3)
      assert length(recent) == 3

      # Sort by timestamp desc, then id desc
      sorted_entries = Enum.sort_by(entries, &{&1.timestamp, &1.id}, :desc)
      assert recent == Enum.take(sorted_entries, 3)
    end

    test "retrieves all entries when n is larger than available", %{
      memory_ref: memory_ref,
      entries: entries
    } do
      assert {:ok, recent} = ETS.recent(memory_ref, 10)
      assert length(recent) == 5
      assert recent == Enum.sort_by(entries, &{&1.timestamp, &1.id}, :desc)
    end

    test "returns empty list for empty table" do
      {:ok, memory_ref} = ETS.initialize([])
      assert {:ok, []} = ETS.recent(memory_ref, 5)
    end
  end

  describe "time window queries" do
    setup do
      {:ok, memory_ref} = ETS.initialize([])
      base_time = System.system_time(:second)

      entries =
        for i <- 0..4 do
          # One hour intervals
          timestamp = base_time + i * 3600

          {:ok, entry} =
            ETS.add(memory_ref, "content #{i}", :observation, %{timestamp: timestamp})

          entry
        end

      %{
        memory_ref: memory_ref,
        entries: entries,
        base_time: base_time
      }
    end

    test "retrieves entries within time window", %{memory_ref: memory_ref, base_time: base_time} do
      # After first hour
      start_time = DateTime.from_unix!(base_time + 3600)
      # After second hour
      end_time = DateTime.from_unix!(base_time + 7200)

      assert {:ok, entries} = ETS.window(memory_ref, start_time, end_time)
      assert length(entries) == 2

      timestamps = Enum.map(entries, & &1.timestamp)

      assert Enum.all?(timestamps, fn ts ->
               ts >= DateTime.to_unix(start_time) && ts <= DateTime.to_unix(end_time)
             end)
    end

    test "returns empty list for non-matching window", %{
      memory_ref: memory_ref,
      base_time: base_time
    } do
      future_time = base_time + 100_000
      start_time = DateTime.from_unix!(future_time)
      end_time = DateTime.from_unix!(future_time + 3600)

      assert {:ok, []} = ETS.window(memory_ref, start_time, end_time)
    end
  end

  describe "search" do
    setup do
      {:ok, memory_ref} = ETS.initialize([])

      entries = [
        {"hello world", 1},
        {"hello elixir", 2},
        {"goodbye world", 3}
      ]

      entries =
        for {content, timestamp} <- entries do
          {:ok, entry} = ETS.add(memory_ref, content, :observation, %{timestamp: timestamp})
          entry
        end

      %{memory_ref: memory_ref, entries: entries}
    end

    test "finds entries matching query", %{memory_ref: memory_ref} do
      assert {:ok, results} = ETS.search(memory_ref, "hello")
      assert length(results) == 2

      assert Enum.all?(results, fn entry ->
               String.contains?(entry.content, "hello")
             end)
    end

    test "returns empty list for non-matching query", %{memory_ref: memory_ref} do
      assert {:ok, []} = ETS.search(memory_ref, "nonexistent")
    end

    test "handles case-insensitive search", %{memory_ref: memory_ref} do
      assert {:ok, results} = ETS.search(memory_ref, "HELLO")
      assert length(results) == 2
    end
  end
end

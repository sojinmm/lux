defmodule Lux.AgentTest do
  use UnitCase, async: true

  alias Lux.Agent
  alias Lux.Memory.SimpleMemory

  @default_timeout 1_000

  # Test modules
  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      description: "A test prism"

    def handler(_params, _context), do: {:ok, %{result: "test"}}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      description: "A test beam"

    sequence do
      step(:test, TestPrism, %{})
    end
  end

  defmodule SimpleAgent do
    @moduledoc false
    use Lux.Agent,
      name: "Simple Agent",
      description: "A simple agent that keeps things simple.",
      goal: "You have one simple goal. Not making things too complicated.",
      prisms: [TestPrism],
      beams: [TestBeam],
      signal_handlers: [{TestSchema, TestPrism}]
  end

  defmodule MemoryAgent do
    @moduledoc false
    use Lux.Agent,
      name: "Memory Agent",
      description: "An agent with memory capabilities",
      goal: "Remember and use past interactions",
      memory_config: %{
        backend: SimpleMemory,
        name: :test_memory
      }

    # We override the chat functions to store the messages in memory here and do not actually call any LLM...
    @impl true
    def chat(agent, message, _opts) do
      response = "Response to: " <> message

      with {:ok, _} <-
             SimpleMemory.add(
               agent.memory_pid,
               message,
               :interaction,
               %{role: :user}
             ) do
        {:ok, _} =
          SimpleMemory.add(
            agent.memory_pid,
            response,
            :interaction,
            %{role: :assistant}
          )

        {:ok, response}
      end
    end
  end

  defmodule TestScheduledPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Scheduled Prism",
      description: "A test prism for scheduled actions"

    def handler(params, _opts) do
      send(Process.whereis(:test_scheduler), {:prism_called, params})
      {:ok, %{result: "scheduled prism success"}}
    end
  end

  defmodule TestScheduledBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Scheduled Beam",
      description: "A test beam for scheduled actions"

    sequence do
      step(:test, TestScheduledPrism, %{test: "beam"})
    end
  end

  describe "memory operations" do
    test "initializes memory on start", %{test: test_name} do
      {:ok, pid} = MemoryAgent.start_link(%{name: "Test Agent #{test_name}"})
      agent = MemoryAgent.get_state(pid)
      assert is_pid(agent.memory_pid)
    end

    test "stores and retrieves interactions", %{test: test_name} do
      {:ok, pid} = MemoryAgent.start_link(%{name: "Test Agent #{test_name}"})

      # Send a message
      {:ok, response} = MemoryAgent.send_message(pid, "Hello")
      assert response == "Response to: Hello"

      # Check stored messages
      agent = :sys.get_state(pid)
      {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 2)

      assert length(recent) == 2
      [assistant_msg, user_msg] = recent

      assert assistant_msg.content == "Response to: Hello"
      assert assistant_msg.type == :interaction
      assert assistant_msg.metadata.role == :assistant

      assert user_msg.content == "Hello"
      assert user_msg.type == :interaction
      assert user_msg.metadata.role == :user
    end
  end

  describe "can be started with a unique name" do
    test "can be started with a unique name", %{test: test_name} do
      name1 = String.replace("Test_Agent_1_#{test_name}", " ", "_")
      name2 = String.replace("Test_Agent_2_#{test_name}", " ", "_")

      # Start two agents with different names
      pid1 = start_supervised!({SimpleAgent, %{name: name1}})
      pid2 = start_supervised!({SimpleAgent, %{name: name2}})

      # Verify they are different processes
      assert pid1 != pid2

      # Get their states to verify they have the correct names
      agent1 = :sys.get_state(pid1)
      agent2 = :sys.get_state(pid2)

      assert agent1.name == name1
      assert agent2.name == name2

      assert_raise RuntimeError, fn ->
        start_supervised!({SimpleAgent, %{name: name1}})
      end
    end
  end

  describe "scheduled actions" do
    setup do
      # Register process to receive test messages
      Process.register(self(), :test_scheduler)
      :ok
    end

    test "executes scheduled prism actions" do
      start_supervised!(
        {SimpleAgent,
         %{
           name: "Scheduled Agent",
           prisms: [TestScheduledPrism],
           scheduled_actions: [
             {TestScheduledPrism, 100, %{test: "prism"}, %{name: "test_prism"}}
           ]
         }}
      )

      # Wait for the scheduled action to run
      assert_receive {:prism_called, %{test: "prism"}}, @default_timeout
    end

    test "executes scheduled beam actions" do
      start_supervised!(
        {SimpleAgent,
         %{
           name: "Scheduled Agent",
           beams: [TestScheduledBeam],
           scheduled_actions: [
             {TestScheduledBeam, 100, %{test: "beam"}, %{name: "test_beam"}}
           ]
         }}
      )

      # Wait for the scheduled action to run. We match on prism_called because the beam is executed by the prism.
      assert_receive {:prism_called, %{test: "beam"}}, @default_timeout
    end

    test "handles invalid modules gracefully" do
      pid =
        start_supervised!(
          {SimpleAgent,
           %{
             name: "Scheduled Agent",
             scheduled_actions: [
               {InvalidModule, 100, %{}, %{name: "invalid"}}
             ]
           }}
        )

      # The agent should not crash
      assert Process.alive?(pid)
    end

    test "uses default name when not provided" do
      start_supervised!(
        {SimpleAgent,
         %{
           name: "Scheduled Agent",
           prisms: [TestScheduledPrism],
           scheduled_actions: [
             {TestScheduledPrism, 100, %{test: "default_name"}, %{}}
           ]
         }}
      )

      # Wait for the scheduled action to run
      assert_receive {:prism_called, %{test: "default_name"}}, @default_timeout
    end
  end

  describe "signal handlers" do
    test "can handle specified signal" do
      signal = Lux.Signal.new(%{schema_id: TestSchema, payload: %{test: "signal"}})
      pid = start_supervised!({SimpleAgent, %{name: "Signal Agent"}})

      :erlang.trace(pid, true, [:call])

      :erlang.trace_pattern(
        {Lux.AgentTest.TestPrism, :handler, 2},
        [{:_, [], [{:return_trace}]}],
        [:local]
      )

      send(pid, {:signal, signal})

      assert_receive {:trace, ^pid, :return_from, {Lux.AgentTest.TestPrism, :handler, _},
                      {:ok, %{result: "test"}}},
                     5000
    end

    test "ignore unspecified signal" do
      signal = %Lux.Signal{schema_id: Unsupported, payload: %{test: "signal"}}
      pid = start_supervised!({SimpleAgent, %{name: "Signal Agent"}})

      :erlang.trace(pid, true, [:call])

      :erlang.trace_pattern(
        {SimpleAgent, :handle_signal, 2},
        [{:_, [], [{:return_trace}]}],
        [:local]
      )

      send(pid, {:signal, signal})

      assert_receive {:trace, ^pid, :return_from, {SimpleAgent, :handle_signal, _}, :ignore}, 5000
    end
  end
end

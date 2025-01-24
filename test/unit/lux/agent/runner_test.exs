defmodule Lux.Agent.RunnerTest do
  use UnitCase, async: true

  alias Lux.Agent.Runner

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

    def steps do
      sequence do
        step(:test, TestPrism, %{})
      end
    end
  end

  describe "start_link/1" do
    test "starts runner process" do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      assert {:ok, pid} = Runner.start_link(agent)
      assert Process.alive?(pid)
    end
  end

  describe "get_agent/1" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid, agent: agent}
    end

    test "returns current agent state", %{pid: pid, agent: agent} do
      assert {:ok, ^agent, ^pid} = Runner.get_agent(pid)
    end
  end

  describe "get_state/1" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid, agent: agent}
    end

    test "returns runner state", %{pid: pid, agent: agent} do
      assert {:ok, %{agent: ^agent, context: context}} = Runner.get_state(pid)
      assert is_map(context)
    end
  end

  describe "schedule_beam/4" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid}
    end

    test "schedules a beam", %{pid: pid} do
      assert :ok = Runner.schedule_beam(pid, TestBeam, "*/5 * * * *")
      {:ok, agent, _} = Runner.get_agent(pid)
      assert length(agent.scheduled_beams) == 1
    end

    test "handles invalid cron expression", %{pid: pid} do
      assert {:error, _} = Runner.schedule_beam(pid, TestBeam, "invalid")
    end
  end

  describe "unschedule_beam/2" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      :ok = Runner.schedule_beam(pid, TestBeam, "*/5 * * * *")
      {:ok, pid: pid}
    end

    test "removes scheduled beam", %{pid: pid} do
      assert :ok = Runner.unschedule_beam(pid, TestBeam)
      {:ok, agent, _} = Runner.get_agent(pid)
      assert agent.scheduled_beams == []
    end
  end

  describe "handle_signal/2" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid}
    end

    test "processes signal", %{pid: pid} do
      signal = %Lux.Signal{schema_id: TestSignalSchema, payload: %{}}
      Runner.handle_signal(pid, signal)
      # Signal is handled asynchronously, so we just ensure it doesn't crash
      assert Process.alive?(pid)
    end
  end

  describe "trigger_learning/1" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid, original_agent: agent}
    end

    test "triggers learning process", %{pid: pid, original_agent: original_agent} do
      Runner.trigger_learning(pid)
      # Wait a bit for async operation
      Process.sleep(100)
      {:ok, updated_agent, _} = Runner.get_agent(pid)
      refute updated_agent.reflection == original_agent.reflection
    end
  end

  describe "periodic tasks" do
    setup do
      # Use shorter intervals for testing
      agent =
        Lux.Agent.new(%{
          name: "Test Agent",
          reflection_interval: 100
        })

      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid, original_agent: agent}
    end

    test "executes scheduled beams", %{pid: pid} do
      # Schedule a beam to run every minute
      :ok = Runner.schedule_beam(pid, TestBeam, "* * * * *")
      # Wait for beam check
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  describe "error handling" do
    setup do
      agent = Lux.Agent.new(%{name: "Test Agent"})
      {:ok, pid} = Runner.start_link(agent)
      {:ok, pid: pid}
    end

    test "survives reflection errors", %{pid: pid} do
      # Force an error by sending invalid context
      send(pid, :reflect)
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "survives beam execution errors", %{pid: pid} do
      # Schedule a beam that will fail
      :ok = Runner.schedule_beam(pid, TestBeam, "* * * * *", fail: true)
      send(pid, :check_beams)
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end
end

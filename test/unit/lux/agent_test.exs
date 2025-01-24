defmodule Lux.AgentTest do
  use UnitCase, async: true

  alias Lux.Agent

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

  describe "new/1" do
    test "creates a new agent with default values" do
      agent = Agent.new(%{})
      assert agent.id != nil
      assert agent.name == "Anonymous Agent"
      assert agent.description == ""
      assert agent.goal == ""
      assert agent.prisms == []
      assert agent.beams == []
      assert agent.lenses == []
      assert agent.memory == []
      assert agent.reflection != nil
      assert agent.reflection_interval == 60_000
    end

    test "creates a new agent with custom values" do
      attrs = %{
        name: "Test Agent",
        description: "A test agent",
        goal: "Test goal",
        prisms: [TestPrism],
        beams: [TestBeam],
        reflection_interval: 30_000,
        llm_config: %{model: "gpt-3.5-turbo"}
      }

      agent = Agent.new(attrs)
      assert agent.name == "Test Agent"
      assert agent.description == "A test agent"
      assert agent.goal == "Test goal"
      assert agent.prisms == [TestPrism]
      assert agent.beams == [TestBeam]
      assert agent.reflection_interval == 30_000
      assert agent.llm_config.model == "gpt-3.5-turbo"
    end
  end

  describe "reflect/2" do
    setup do
      agent =
        Agent.new(%{
          name: "Test Agent",
          goal: "Test goal",
          prisms: [TestPrism],
          beams: [TestBeam]
        })

      context = %{
        current_task: "test task",
        environment: "test"
      }

      {:ok, agent: agent, context: context}
    end

    test "performs reflection and returns actions", %{agent: agent, context: context} do
      {:ok, results, updated_agent} = Agent.reflect(agent, context)

      assert is_tuple(results)
      assert elem(results, 0) == :ok
      assert is_list(elem(results, 1))

      assert updated_agent.reflection.last_reflection_time >
               agent.reflection.last_reflection_time
    end

    test "limits number of actions based on config", %{agent: agent, context: context} do
      agent = %{
        agent
        | reflection_config: %{agent.reflection_config | max_actions_per_reflection: 1}
      }

      {:ok, {:ok, actions}, _updated_agent} = Agent.reflect(agent, context)
      assert length(actions) <= 1
    end
  end

  describe "schedule_beam/4" do
    setup do
      agent = Agent.new(%{name: "Test Agent"})
      {:ok, agent: agent}
    end

    test "schedules a beam with valid cron expression", %{agent: agent} do
      {:ok, updated_agent} = Agent.schedule_beam(agent, TestBeam, "*/5 * * * *")
      assert length(updated_agent.scheduled_beams) == 1
      {module, cron, _opts} = List.first(updated_agent.scheduled_beams)
      assert module == TestBeam
      assert cron == "*/5 * * * *"
    end

    test "returns error with invalid cron expression", %{agent: agent} do
      assert {:error, {:invalid_cron_expression, _}} =
               Agent.schedule_beam(agent, TestBeam, "invalid")
    end

    test "accepts options when scheduling", %{agent: agent} do
      opts = [input: %{test: true}]
      {:ok, updated_agent} = Agent.schedule_beam(agent, TestBeam, "*/5 * * * *", opts)
      {_module, _cron, beam_opts} = List.first(updated_agent.scheduled_beams)
      assert beam_opts == opts
    end
  end

  describe "unschedule_beam/2" do
    setup do
      agent = Agent.new(%{name: "Test Agent"})
      {:ok, agent} = Agent.schedule_beam(agent, TestBeam, "*/5 * * * *")
      {:ok, agent: agent}
    end

    test "removes scheduled beam", %{agent: agent} do
      {:ok, updated_agent} = Agent.unschedule_beam(agent, TestBeam)
      assert updated_agent.scheduled_beams == []
    end

    test "handles non-existent beam", %{agent: agent} do
      {:ok, updated_agent} = Agent.unschedule_beam(agent, NonExistentBeam)
      assert length(updated_agent.scheduled_beams) == 1
    end
  end

  describe "get_due_beams/1" do
    setup do
      agent = Agent.new(%{name: "Test Agent"})
      # Schedule beam to run every minute
      {:ok, agent} = Agent.schedule_beam(agent, TestBeam, "* * * * *")
      {:ok, agent: agent}
    end

    test "returns beams that should run", %{agent: agent} do
      due_beams = Agent.get_due_beams(agent)
      assert length(due_beams) == 1
      {module, _cron, _opts} = List.first(due_beams)
      assert module == TestBeam
    end
  end

  describe "collaborate/4" do
    setup do
      agent =
        Agent.new(%{
          name: "Test Agent",
          collaboration_config: %{
            can_delegate: true,
            can_request_help: true,
            trusted_agents: ["trusted-agent"],
            collaboration_protocols: [:ask, :tell, :delegate, :request_review]
          }
        })

      target_agent =
        Agent.new(%{
          id: "trusted-agent",
          name: "Trusted Agent"
        })

      {:ok, agent: agent, target_agent: target_agent}
    end

    test "allows collaboration with trusted agent", %{
      agent: agent,
      target_agent: target_agent
    } do
      result = Agent.collaborate(agent, target_agent, :ask, "test question")
      assert {:ok, :not_implemented} = result
    end

    test "prevents collaboration with untrusted agent", %{agent: agent} do
      untrusted_agent = Agent.new(%{id: "untrusted", name: "Untrusted"})
      result = Agent.collaborate(agent, untrusted_agent, :ask, "test")
      assert {:error, :unauthorized} = result
    end

    test "respects collaboration protocol restrictions", %{
      agent: agent,
      target_agent: target_agent
    } do
      agent = %{
        agent
        | collaboration_config: %{agent.collaboration_config | collaboration_protocols: [:ask]}
      }

      assert {:error, :unauthorized} = Agent.collaborate(agent, target_agent, :tell, "test")
    end

    test "respects delegation permission", %{agent: agent, target_agent: target_agent} do
      agent = %{
        agent
        | collaboration_config: %{agent.collaboration_config | can_delegate: false}
      }

      assert {:error, :unauthorized} =
               Agent.collaborate(agent, target_agent, :delegate, "test task")
    end
  end
end

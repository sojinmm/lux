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
    end

    test "creates a new agent with custom values" do
      attrs = %{
        name: "Test Agent",
        description: "A test agent",
        goal: "Test goal",
        prisms: [TestPrism],
        beams: [TestBeam],
        llm_config: %{model: "gpt-3.5-turbo"}
      }

      agent = Agent.new(attrs)
      assert agent.name == "Test Agent"
      assert agent.description == "A test agent"
      assert agent.goal == "Test goal"
      assert agent.prisms == [TestPrism]
      assert agent.beams == [TestBeam]
      assert agent.llm_config.model == "gpt-3.5-turbo"
    end
  end
end

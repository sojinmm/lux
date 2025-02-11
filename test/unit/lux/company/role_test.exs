defmodule Lux.Company.RoleTest do
  use UnitCase, async: true

  alias Lux.Company.Role

  # Test module to use as a local agent
  defmodule TestAgent do
    @moduledoc false
    use Lux.Agent

    def new(opts \\ %{}) do
      Lux.Agent.new(%{
        name: opts[:name] || "Test Agent",
        description: "A test agent",
        goal: "Help with testing",
        capabilities: opts[:capabilities] || []
      })
    end
  end

  describe "new/1" do
    test "creates role with local agent" do
      role = Role.new(%{
        type: :member,
        name: "Test Role",
        agent: TestAgent,
        capabilities: ["test"],
        goal: "Test things"
      })

      assert role.agent == TestAgent
      assert role.type == :member
      assert role.name == "Test Role"
      assert role.goal == "Test things"
      assert "test" in role.capabilities
      assert is_binary(role.id)  # Should generate an ID
    end

    test "creates role with remote agent" do
      role = Role.new(%{
        type: :member,
        name: "Remote Role",
        agent: {"agent-123", RemoteHub},
        capabilities: ["test"],
        goal: "Remote testing"
      })

      assert role.agent == {"agent-123", RemoteHub}
      assert role.hub == RemoteHub
      assert is_binary(role.id)
    end

    test "creates role without agent" do
      role = Role.new(%{
        type: :member,
        name: "Vacant Role",
        capabilities: ["test"],
        goal: "To be filled"
      })

      assert role.agent == nil
      assert is_binary(role.id)
    end
  end

  describe "validate/1" do
    test "validates role with local agent" do
      role = Role.new(%{
        type: :member,
        name: "Test Role",
        agent: TestAgent,
        capabilities: ["test"]
      })

      assert {:ok, _} = Role.validate(role)
    end

    test "validates role with remote agent" do
      role = Role.new(%{
        type: :member,
        name: "Remote Role",
        agent: {"agent-123", RemoteHub},
        capabilities: ["test"]
      })

      assert {:ok, _} = Role.validate(role)
    end

    test "validates role without agent" do
      role = Role.new(%{
        type: :member,
        name: "Vacant Role",
        capabilities: ["test"]
      })

      assert {:ok, _} = Role.validate(role)
    end

    test "fails validation with invalid agent specification" do
      role = Role.new(%{
        type: :member,
        name: "Invalid Role",
        agent: :invalid,
        capabilities: ["test"]
      })

      assert {:error, :invalid_agent_specification} = Role.validate(role)
    end

    test "fails validation with invalid type" do
      role = Role.new(%{
        type: :invalid,
        name: "Invalid Role",
        capabilities: ["test"]
      })

      assert {:error, "Invalid role type"} = Role.validate(role)
    end

    test "fails validation with empty name" do
      role = Role.new(%{
        type: :member,
        name: "",
        capabilities: ["test"]
      })

      assert {:error, "Role name must be a non-empty string"} = Role.validate(role)
    end

    test "fails validation with invalid capabilities" do
      role = Role.new(%{
        type: :member,
        name: "Test Role",
        capabilities: [:not_a_string]
      })

      assert {:error, "Capabilities must be strings"} = Role.validate(role)
    end
  end
end

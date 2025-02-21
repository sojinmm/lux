defmodule Lux.Agent.ConfigTest do
  use UnitCase, async: true

  alias Lux.Agent.Config

  describe "validate/1" do
    test "validates valid config" do
      config = %Config{
        id: "test-agent",
        name: "Test Agent",
        description: "A test agent",
        goal: "Testing",
        module: "Test.Agent"
      }

      assert :ok = Config.validate(config)
    end

    test "validates required fields" do
      config = %Config{
        name: "Test Agent"
      }

      assert {:error, {:missing_fields, missing}} = Config.validate(config)
      assert :id in missing
      assert :description in missing
      assert :goal in missing
      assert :module in missing
    end

    test "validates field types" do
      config = %Config{
        id: 123,
        name: "Test Agent",
        description: "A test agent",
        goal: "Testing",
        module: "Test.Agent"
      }

      assert {:error, {:invalid_type, :id, :string}} = Config.validate(config)
    end
  end
end

defmodule Lux.Unit.Agent.Config.LoaderTest do
  use UnitCase, async: true

  alias Lux.Agent
  alias Lux.Agent.Config.Loader

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join(System.tmp_dir!(), "lux_test_#{:rand.uniform(1000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "load/1" do
    test "loads a single agent from a JSON file", %{tmp_dir: tmp_dir} do
      config = %{
        "id" => "test-agent",
        "name" => "Test Agent",
        "description" => "A test agent",
        "goal" => "Testing",
        "module" => "Elixir.Test.JsonAgent",
        "template" => "default",
        "template_opts" => %{},
        "prisms" => [],
        "beams" => [],
        "lenses" => [],
        "accepts_signals" => [],
        "llm_config" => %{},
        "memory_config" => nil,
        "scheduled_actions" => [],
        "signal_handlers" => [],
        "metadata" => %{}
      }

      path = Path.join(tmp_dir, "agent.json")
      File.write!(path, Jason.encode!(config))

      assert {:ok, agent} = Loader.load(path)
      assert %Agent{} = agent
      assert agent.id == "test-agent"
      assert agent.name == "Test Agent"
    end

    test "loads multiple agents from a directory", %{tmp_dir: tmp_dir} do
      configs = [
        %{
          "id" => "agent-1",
          "name" => "Agent 1",
          "description" => "First test agent",
          "goal" => "Testing 1",
          "module" => "Elixir.Test.JsonAgent1",
          "template" => "default",
          "template_opts" => %{},
          "prisms" => [],
          "beams" => [],
          "lenses" => [],
          "accepts_signals" => [],
          "llm_config" => %{},
          "memory_config" => nil,
          "scheduled_actions" => [],
          "signal_handlers" => [],
          "metadata" => %{}
        },
        %{
          "id" => "agent-2",
          "name" => "Agent 2",
          "description" => "Second test agent",
          "goal" => "Testing 2",
          "module" => "Elixir.Test.Agent2",
          "template" => "default",
          "template_opts" => %{},
          "prisms" => [],
          "beams" => [],
          "lenses" => [],
          "accepts_signals" => [],
          "llm_config" => %{},
          "memory_config" => nil,
          "scheduled_actions" => [],
          "signal_handlers" => [],
          "metadata" => %{}
        }
      ]

      Enum.each(configs, fn config ->
        path = Path.join(tmp_dir, "#{config["id"]}.json")
        File.write!(path, Jason.encode!(config))
      end)

      assert {:ok, agents} = Loader.load(tmp_dir)
      assert length(agents) == 2
      assert Enum.all?(agents, &match?(%Agent{}, &1))
      assert agents |> Enum.map(& &1.id) |> Enum.sort() == ["agent-1", "agent-2"]
    end

    test "handles empty directory", %{tmp_dir: tmp_dir} do
      assert {:error, :no_valid_agents_found} = Loader.load(tmp_dir)
    end

    test "validates required fields", %{tmp_dir: tmp_dir} do
      config = %{
        "name" => "Invalid Agent"
      }

      path = Path.join(tmp_dir, "invalid.json")
      File.write!(path, Jason.encode!(config))

      assert {:error, {:missing_fields, missing}} = Loader.load(path)
      assert "id" in missing
      assert "description" in missing
      assert "goal" in missing
    end

    test "converts module names to atoms", %{tmp_dir: tmp_dir} do
      config = %{
        "id" => "test-agent",
        "name" => "Test Agent",
        "description" => "A test agent",
        "goal" => "Testing",
        "module" => "Elixir.Test.JsonAgent",
        "template" => "default",
        "template_opts" => %{},
        "prisms" => ["Elixir.Test.Prism"],
        "beams" => ["Elixir.Test.Beam"],
        "lenses" => ["Elixir.Test.Lens"],
        "accepts_signals" => ["Elixir.Test.Signal"],
        "memory_config" => %{
          "backend" => "Elixir.Test.Memory",
          "name" => "test_memory"
        },
        "scheduled_actions" => [],
        "signal_handlers" => [],
        "llm_config" => %{},
        "metadata" => %{}
      }

      path = Path.join(tmp_dir, "agent.json")
      File.write!(path, Jason.encode!(config))

      assert {:ok, agent} = Loader.load(path)
      assert agent.module == :"Elixir.Test.JsonAgent"
      assert agent.prisms == [:"Elixir.Test.Prism"]
      assert agent.beams == [:"Elixir.Test.Beam"]
      assert agent.lenses == [:"Elixir.Test.Lens"]
      assert agent.accepts_signals == [:"Elixir.Test.Signal"]
      assert agent.memory_config.backend == :"Elixir.Test.Memory"
      assert agent.memory_config.name == :test_memory
    end

    test "handles invalid JSON file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.json")
      File.write!(path, "invalid json")
      assert {:error, :invalid_json} = Loader.load(path)
    end

    test "handles non-existent path" do
      assert {:error, :invalid_path} = Loader.load("non_existent_path")
    end

    test "loads valid agents and skips invalid ones in directory", %{tmp_dir: tmp_dir} do
      valid_config = %{
        "id" => "valid-agent",
        "name" => "Valid Agent",
        "description" => "A valid agent",
        "goal" => "Testing",
        "module" => "Elixir.Test.ValidAgent",
        "template" => "default",
        "template_opts" => %{},
        "prisms" => [],
        "beams" => [],
        "lenses" => [],
        "accepts_signals" => [],
        "llm_config" => %{},
        "memory_config" => nil,
        "scheduled_actions" => [],
        "signal_handlers" => [],
        "metadata" => %{}
      }

      invalid_config = %{
        "name" => "Invalid Agent"
      }

      File.write!(Path.join(tmp_dir, "valid.json"), Jason.encode!(valid_config))
      File.write!(Path.join(tmp_dir, "invalid.json"), Jason.encode!(invalid_config))
      File.write!(Path.join(tmp_dir, "not_json.json"), "invalid json")

      assert {:ok, agents} = Loader.load(tmp_dir)
      assert length(agents) == 1
      assert hd(agents).id == "valid-agent"
    end
  end
end

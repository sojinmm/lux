defmodule Lux.SpecterTest do
  use ExUnit.Case, async: true

  alias Lux.Specter

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
    test "creates a new specter with default values" do
      specter = Specter.new(%{})
      assert specter.id != nil
      assert specter.name == "Anonymous Specter"
      assert specter.description == ""
      assert specter.goal == ""
      assert specter.prisms == []
      assert specter.beams == []
      assert specter.lenses == []
      assert specter.memory == []
      assert specter.reflection != nil
      assert specter.reflection_interval == 60_000
    end

    test "creates a new specter with custom values" do
      attrs = %{
        name: "Test Specter",
        description: "A test specter",
        goal: "Test goal",
        prisms: [TestPrism],
        beams: [TestBeam],
        reflection_interval: 30_000,
        llm_config: %{model: "gpt-3.5-turbo"}
      }

      specter = Specter.new(attrs)
      assert specter.name == "Test Specter"
      assert specter.description == "A test specter"
      assert specter.goal == "Test goal"
      assert specter.prisms == [TestPrism]
      assert specter.beams == [TestBeam]
      assert specter.reflection_interval == 30_000
      assert specter.llm_config.model == "gpt-3.5-turbo"
    end
  end

  describe "reflect/2" do
    setup do
      specter =
        Specter.new(%{
          name: "Test Specter",
          goal: "Test goal",
          prisms: [TestPrism],
          beams: [TestBeam]
        })

      context = %{
        current_task: "test task",
        environment: "test"
      }

      {:ok, specter: specter, context: context}
    end

    test "performs reflection and returns actions", %{specter: specter, context: context} do
      {:ok, results, updated_specter} = Specter.reflect(specter, context)

      assert is_tuple(results)
      assert elem(results, 0) == :ok
      assert is_list(elem(results, 1))

      assert updated_specter.reflection.last_reflection_time >
               specter.reflection.last_reflection_time
    end

    test "limits number of actions based on config", %{specter: specter, context: context} do
      specter = %{
        specter
        | reflection_config: %{specter.reflection_config | max_actions_per_reflection: 1}
      }

      {:ok, {:ok, actions}, _updated_specter} = Specter.reflect(specter, context)
      assert length(actions) <= 1
    end
  end

  describe "schedule_beam/4" do
    setup do
      specter = Specter.new(%{name: "Test Specter"})
      {:ok, specter: specter}
    end

    test "schedules a beam with valid cron expression", %{specter: specter} do
      {:ok, updated_specter} = Specter.schedule_beam(specter, TestBeam, "*/5 * * * *")
      assert length(updated_specter.scheduled_beams) == 1
      {module, cron, _opts} = List.first(updated_specter.scheduled_beams)
      assert module == TestBeam
      assert cron == "*/5 * * * *"
    end

    test "returns error with invalid cron expression", %{specter: specter} do
      assert {:error, {:invalid_cron_expression, _}} =
               Specter.schedule_beam(specter, TestBeam, "invalid")
    end

    test "accepts options when scheduling", %{specter: specter} do
      opts = [input: %{test: true}]
      {:ok, updated_specter} = Specter.schedule_beam(specter, TestBeam, "*/5 * * * *", opts)
      {_module, _cron, beam_opts} = List.first(updated_specter.scheduled_beams)
      assert beam_opts == opts
    end
  end

  describe "unschedule_beam/2" do
    setup do
      specter = Specter.new(%{name: "Test Specter"})
      {:ok, specter} = Specter.schedule_beam(specter, TestBeam, "*/5 * * * *")
      {:ok, specter: specter}
    end

    test "removes scheduled beam", %{specter: specter} do
      {:ok, updated_specter} = Specter.unschedule_beam(specter, TestBeam)
      assert updated_specter.scheduled_beams == []
    end

    test "handles non-existent beam", %{specter: specter} do
      {:ok, updated_specter} = Specter.unschedule_beam(specter, NonExistentBeam)
      assert length(updated_specter.scheduled_beams) == 1
    end
  end

  describe "get_due_beams/1" do
    setup do
      specter = Specter.new(%{name: "Test Specter"})
      # Schedule beam to run every minute
      {:ok, specter} = Specter.schedule_beam(specter, TestBeam, "* * * * *")
      {:ok, specter: specter}
    end

    test "returns beams that should run", %{specter: specter} do
      due_beams = Specter.get_due_beams(specter)
      assert length(due_beams) == 1
      {module, _cron, _opts} = List.first(due_beams)
      assert module == TestBeam
    end
  end

  describe "collaborate/4" do
    setup do
      specter =
        Specter.new(%{
          name: "Test Specter",
          collaboration_config: %{
            can_delegate: true,
            can_request_help: true,
            trusted_specters: ["trusted-specter"],
            collaboration_protocols: [:ask, :tell, :delegate, :request_review]
          }
        })

      target_specter =
        Specter.new(%{
          id: "trusted-specter",
          name: "Trusted Specter"
        })

      {:ok, specter: specter, target_specter: target_specter}
    end

    test "allows collaboration with trusted specter", %{
      specter: specter,
      target_specter: target_specter
    } do
      result = Specter.collaborate(specter, target_specter, :ask, "test question")
      assert {:ok, :not_implemented} = result
    end

    test "prevents collaboration with untrusted specter", %{specter: specter} do
      untrusted_specter = Specter.new(%{id: "untrusted", name: "Untrusted"})
      result = Specter.collaborate(specter, untrusted_specter, :ask, "test")
      assert {:error, :unauthorized} = result
    end

    test "respects collaboration protocol restrictions", %{
      specter: specter,
      target_specter: target_specter
    } do
      specter = %{
        specter
        | collaboration_config: %{specter.collaboration_config | collaboration_protocols: [:ask]}
      }

      assert {:error, :unauthorized} = Specter.collaborate(specter, target_specter, :tell, "test")
    end

    test "respects delegation permission", %{specter: specter, target_specter: target_specter} do
      specter = %{
        specter
        | collaboration_config: %{specter.collaboration_config | can_delegate: false}
      }

      assert {:error, :unauthorized} =
               Specter.collaborate(specter, target_specter, :delegate, "test task")
    end
  end
end

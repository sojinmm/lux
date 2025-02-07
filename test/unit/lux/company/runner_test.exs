defmodule Lux.Company.RunnerTest do
  use ExUnit.Case, async: true

  alias Lux.Company.{Role, Plan, Runner}
  alias Lux.Signal

  # Test modules
  defmodule TestAgent do
    use Lux.Agent

    def new(opts \\ %{}) do
      Lux.Agent.new(%{
        name: opts[:name] || "Test Agent",
        description: "A test agent",
        goal: "Help with testing",
        capabilities: opts[:capabilities] || []
      })
    end

    @impl true
    def handle_signal(_agent, signal) do
      # Echo back a response immediately
      response = Signal.new(%{
        id: Lux.UUID.generate(),
        schema_id: Lux.Schemas.TaskSignal,
        payload: %{result: "Completed #{signal.payload.task}"},
        sender: "test_agent",
        recipient: signal.sender
      })
      Lux.Signal.Router.route(response, router: Lux.Signal.Router.Local)
      :ok
    end
  end

  defmodule TestCompany do
    use Lux.Company

    company do
      name "Test Company"
      mission "Testing the runner"

      has_ceo "Test CEO" do
        agent TestAgent
        goal "Direct testing activities"
        can "plan"
        can "review"
      end

      has_member "Test Researcher" do
        agent TestAgent
        goal "Research test cases"
        can "research"
        can "analyze"
      end

      has_member "Test Writer" do
        agent TestAgent
        goal "Write test content"
        can "write"
        can "edit"
      end
    end

    plan :test_plan do
      input do
        field "test_input"
      end

      steps """
      1. Research test requirements
      2. Plan test approach
      3. Write test cases
      4. Review results
      """
    end
  end

  describe "plan execution" do
    setup do
      # Generate a unique test ID for all process names
      test_id = System.unique_integer([:positive])

      # Use unique names for all processes
      router_name = :"signal_router_#{test_id}"
      hub_name = :"agent_hub_#{test_id}"
      runner_name = :"company_runner_#{test_id}"

      # Start Task.Supervisor with unique name
      task_sup_name = :"task_supervisor_#{test_id}"
      start_supervised!({Task.Supervisor, name: task_sup_name})

      # Start router and hub with unique names
      start_supervised!({Lux.Signal.Router.Local, name: router_name})
      start_supervised!({Lux.AgentHub, name: hub_name})

      company = TestCompany.__company__()
      # Add IDs to roles
      company = %{company |
        ceo: Map.put(company.ceo, :id, Lux.UUID.generate()),
        members: Enum.map(company.members, &Map.put(&1, :id, Lux.UUID.generate()))
      }

      # Start the runner with explicit name and configuration
      {:ok, pid} = Runner.start_link({company, %{
        router: router_name,
        hub: hub_name,
        name: runner_name,
        task_supervisor: task_sup_name
      }})

      # Register agents with the hub
      :ok = Lux.AgentHub.register(hub_name, company.ceo, self(), ["plan", "review"])
      Enum.each(company.members, fn member ->
        :ok = Lux.AgentHub.register(hub_name, member, self(), member.capabilities)
      end)

      {:ok,
        runner: pid,
        runner_name: runner_name,
        company: company,
        router: router_name,
        hub: hub_name,
        task_supervisor: task_sup_name
      }
    end

    test "executes plan steps in sequence", %{runner_name: runner_name} = context do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.run_plan(runner_name, :test_plan, params)

      # Wait for plan completion with increased timeout
      assert_receive {:plan_completed, ^plan_id, {:ok, result}}, 10_000

      assert length(result.results) == 4
      [step4, step3, step2, step1] = result.results

      assert step1.task == "research test requirements"
      assert step1.agent == "Test Researcher"
      assert step1.status == :completed

      assert step2.task == "plan test approach"
      assert step2.agent == "Test CEO"
      assert step2.status == :completed

      assert step3.task == "write test cases"
      assert step3.agent == "Test Writer"
      assert step3.status == :completed

      assert step4.task == "review results"
      assert step4.agent == "Test CEO"
      assert step4.status == :completed
    end

    test "tracks plan progress", %{runner_name: runner_name} = context do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.run_plan(runner_name, :test_plan, params)

      # Check progress updates with increased timeouts
      assert_receive {:plan_progress, ^plan_id, 25}, 2000
      assert_receive {:plan_progress, ^plan_id, 50}, 2000
      assert_receive {:plan_progress, ^plan_id, 75}, 2000
      assert_receive {:plan_progress, ^plan_id, 100}, 2000
    end

    test "validates plan inputs", %{runner_name: runner_name} = context do
      # Missing required input
      assert {:error, reason} = Runner.run_plan(runner_name, :test_plan, %{})
      assert String.contains?(reason, "Missing required inputs")

      # Extra input
      assert {:error, reason} = Runner.run_plan(runner_name, :test_plan, %{
        "test_input" => "example",
        "extra" => "invalid"
      })
      assert String.contains?(reason, "Unexpected inputs provided")
    end

    test "handles non-existent plans", %{runner_name: runner_name} = context do
      assert {:error, "Plan not found"} = Runner.run_plan(runner_name, :invalid_plan, %{})
    end

    test "handles agent failures", %{runner_name: _runner_name} do
      # TODO: Add test for agent failure scenarios
      # This will require modifying the TestAgent to simulate failures
    end
  end
end

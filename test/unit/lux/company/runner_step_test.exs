defmodule Lux.Company.RunnerStepTest do
  use UnitCase, async: true

  alias Lux.Company.Runner
  alias Lux.Signal
  alias Lux.Signal.Router
  alias Lux.AgentHub

  # Test modules
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

    @impl true
    def handle_signal(_agent, signal) do
      # Echo back a response immediately
      response =
        Signal.new(%{
          id: Lux.UUID.generate(),
          schema_id: Lux.Schemas.TaskSignal,
          payload: %{result: "Completed #{signal.payload.task}"},
          sender: signal.recipient,  # Use our ID as sender
          recipient: signal.sender   # Send back to original sender
        })

      # Get router config from process dictionary
      router = Process.get(:signal_router)
      hub = signal.payload.response_hub || Process.get(:agent_hub)

      # Subscribe to response first
      :ok = Router.subscribe(response.id, router: router)

      # Then route the response
      :ok = Router.route(response, router: router, hub: hub)
      :ok
    end
  end

  defmodule TestCompany do
    @moduledoc false
    use Lux.Company

    company do
      name("Test Company")
      mission("Testing the runner")

      has_ceo "Test CEO" do
        goal("Direct testing activities")
        can("plan")
        can("review")
        agent(TestAgent)
      end

      has_member "Test Researcher" do
        goal("Research test cases")
        can("research")
        can("analyze")
        agent(TestAgent)
      end

      has_member "Test Writer" do
        goal("Write test content")
        can("write")
        can("edit")
        agent(TestAgent)
      end
    end

    plan :test_plan do
      input do
        field("test_input")
      end

      steps("""
      1. Research test requirements
      2. Plan test approach
      3. Write test cases
      4. Review results
      """)
    end
  end

  describe "step-by-step plan execution" do
    setup do
      test_id = System.unique_integer([:positive])
      router_name = :"signal_router_#{test_id}"
      hub_name = :"agent_hub_#{test_id}"

      # Start router and hub
      start_supervised!({Router.Local, name: router_name})
      start_supervised!({AgentHub, name: hub_name})

      # Store router and hub in process dictionary for agents to use
      Process.put(:signal_router, router_name)
      Process.put(:agent_hub, hub_name)

      # Create company with unique IDs
      company = TestCompany.__company__()
      company = %{company |
        ceo: Map.put(company.ceo, :id, Lux.UUID.generate()),
        members: Enum.map(company.members, &Map.put(&1, :id, Lux.UUID.generate()))
      }

      # Start and register agents
      [ceo_role | other_members] = [company.ceo | company.members]
      {:ok, ceo_pid} = start_supervised({TestAgent, name: :"ceo_#{test_id}"})
      :ok = AgentHub.register(hub_name, %{id: ceo_role.id}, ceo_pid, ["plan", "review"])

      [researcher_role, writer_role] = other_members
      {:ok, researcher_pid} = start_supervised({TestAgent, name: :"researcher_#{test_id}"})
      :ok = AgentHub.register(hub_name, %{id: researcher_role.id}, researcher_pid, ["research", "analyze"])

      {:ok, writer_pid} = start_supervised({TestAgent, name: :"writer_#{test_id}"})
      :ok = AgentHub.register(hub_name, %{id: writer_role.id}, writer_pid, ["write", "edit"])

      # Start the runner
      runner_name = :"runner_#{test_id}"
      {:ok, _pid} = start_supervised(
        {Runner,
         {company,
          %{
            router: router_name,
            hub: hub_name,
            name: runner_name
          }}}
      )

      %{
        runner_name: runner_name,
        router_name: router_name,
        hub_name: hub_name,
        company: company
      }
    end

    test "starts a plan without executing steps", %{runner_name: runner} do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.start_plan(runner, :test_plan, params)

      {:ok, plan_state} = Runner.get_plan_state(runner, plan_id)
      assert plan_state.status == :initialized
      assert plan_state.current_step == 0
      assert plan_state.results == []
    end

    test "executes single step successfully", %{runner_name: runner} do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.start_plan(runner, :test_plan, params)

      {:ok, result} = Runner.execute_next_step(runner, plan_id)
      assert result.task =~ "research"
      assert result.status == :completed

      {:ok, plan_state} = Runner.get_plan_state(runner, plan_id)
      assert plan_state.status == :running
      assert plan_state.current_step == 1
      assert length(plan_state.results) == 1
    end

    test "executes all steps one by one", %{runner_name: runner} do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.start_plan(runner, :test_plan, params)

      # First step
      {:ok, result1} = Runner.execute_next_step(runner, plan_id)
      assert result1.task =~ "research"

      # Second step
      {:ok, result2} = Runner.execute_next_step(runner, plan_id)
      assert result2.task =~ "plan"

      # Third step
      {:ok, result3} = Runner.execute_next_step(runner, plan_id)
      assert result3.task =~ "write"

      # Fourth (final) step
      {:complete, results} = Runner.execute_next_step(runner, plan_id)
      assert length(results) == 4
      [result4 | _] = results
      assert result4.task =~ "review"

      # Verify final state
      {:ok, plan_state} = Runner.get_plan_state(runner, plan_id)
      assert plan_state.status == :completed
      assert plan_state.current_step == 4
      assert length(plan_state.results) == 4
    end

    test "handles non-existent plans", %{runner_name: runner} do
      assert {:error, :no_plan} = Runner.execute_next_step(runner, "nonexistent")
      assert {:error, :not_found} = Runner.get_plan_state(runner, "nonexistent")
    end

    test "handles completed plans", %{runner_name: runner} do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.start_plan(runner, :test_plan, params)

      # Execute all steps
      {:ok, _} = Runner.execute_next_step(runner, plan_id)
      {:ok, _} = Runner.execute_next_step(runner, plan_id)
      {:ok, _} = Runner.execute_next_step(runner, plan_id)
      {:complete, _} = Runner.execute_next_step(runner, plan_id)

      # Try to execute another step
      assert {:error, :plan_completed} = Runner.execute_next_step(runner, plan_id)
    end

    test "handles invalid plan inputs", %{runner_name: runner} do
      # Missing required input
      params = %{}
      assert {:error, _} = Runner.start_plan(runner, :test_plan, params)

      # Invalid plan name
      assert {:error, :plan_not_found} = Runner.start_plan(runner, :nonexistent_plan, %{})
    end
  end
end

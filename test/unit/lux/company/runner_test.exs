defmodule Lux.Company.RunnerTest do
  use UnitCase, async: true

  alias Lux.Company.Plan
  alias Lux.Company.Role
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
        # Will be filled with a remote agent
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

  describe "plan execution" do
    setup do
      test_id = System.unique_integer([:positive])
      router_name = :"signal_router_#{test_id}"
      hub_name = :"agent_hub_#{test_id}"
      remote_hub_name = :"remote_hub_#{test_id}"

      # Start router and hubs
      start_supervised!({Router.Local, name: router_name})
      start_supervised!({AgentHub, name: hub_name})
      start_supervised!({AgentHub, name: remote_hub_name})

      # Store router and hub in process dictionary for agents to use
      Process.put(:signal_router, router_name)
      Process.put(:agent_hub, hub_name)

      # Setup task supervisor
      task_sup_name = :"task_supervisor_#{test_id}"
      start_supervised!({Task.Supervisor, name: task_sup_name})

      # Create company with unique IDs
      company = TestCompany.__company__()
      company = %{company |
        ceo: Map.put(company.ceo, :id, Lux.UUID.generate()),
        members: Enum.map(company.members, &Map.put(&1, :id, Lux.UUID.generate()))
      }

      # Start and register local agents
      {:ok, ceo_pid} = start_supervised({TestAgent, name: :"ceo_#{test_id}"})
      {:ok, writer_pid} = start_supervised({TestAgent, name: :"writer_#{test_id}"})

      ceo = :sys.get_state(ceo_pid)
      writer = :sys.get_state(writer_pid)

      # Register local agents with their IDs
      [ceo_role | other_members] = [company.ceo | company.members]
      :ok = AgentHub.register(hub_name, %{id: ceo_role.id}, ceo_pid, ["plan", "review"])

      [writer_role, researcher_role] = other_members
      :ok = AgentHub.register(hub_name, %{id: writer_role.id}, writer_pid, ["write", "edit"])

      # Register a remote agent for research
      researcher_id = "researcher-#{test_id}"
      :ok = AgentHub.register(remote_hub_name, %{id: researcher_id}, self(), ["research", "analyze"])

      # Update the researcher member to use the remote agent
      researcher_role = %{researcher_role |
        agent: {researcher_id, remote_hub_name},
        hub: remote_hub_name,
        capabilities: ["research", "analyze"]  # Ensure capabilities match
      }
      company = %{company | members: [writer_role, researcher_role]}

      # Start the runner with explicit configuration
      runner_name = :"runner_#{test_id}"
      {:ok, _pid} = start_supervised(
        {Runner,
         {company,
          %{
            router: router_name,
            hub: hub_name,
            name: runner_name,
            task_supervisor: task_sup_name
          }}}
      )

      %{
        runner_name: runner_name,
        router_name: router_name,
        hub_name: hub_name,
        remote_hub_name: remote_hub_name,
        company: company
      }
    end

    test "executes plan with mixed local and remote agents", %{runner_name: runner_name} = context do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.run_plan(runner_name, :test_plan, params)

      # Simulate remote agent response
      receive do
        {:signal, signal} ->
          if String.contains?(signal.payload.task, "research") do
            response = Signal.new(%{
              id: Lux.UUID.generate(),
              schema_id: Lux.Schemas.TaskSignal,
              payload: %{result: "Research completed"},
              sender: signal.recipient,
              recipient: signal.sender
            })
            Router.route(response, router: context.router_name, hub: context.hub_name)
          else
            flunk("Received unexpected task: #{inspect(signal.payload.task)}")
          end
      after
        1000 -> flunk("No research task received")
      end

      # Wait for plan completion
      assert_receive {:plan_completed, ^plan_id, {:ok, result}}, 5000

      assert length(result.results) == 4
      [step4, step3, step2, step1] = result.results

      assert step1.task =~ "research"
      assert step1.status == :completed

      assert step2.task =~ "plan"
      assert step2.status == :completed

      assert step3.task =~ "write"
      assert step3.status == :completed

      assert step4.task =~ "review"
      assert step4.status == :completed
    end

    test "handles remote agent failures", %{runner_name: runner_name} = _context do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Runner.run_plan(runner_name, :test_plan, params)

      # Let the remote agent task timeout
      assert_receive {:plan_failed, ^plan_id, _error}, 5000
    end
  end
end

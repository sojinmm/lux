defmodule Lux.Company.ExecutionEngine.SupervisorTest do
  use ExUnit.Case, async: true

  alias Lux.Company.ExecutionEngine.Supervisor, as: ExecutionSupervisor
  alias Lux.Company.Objective

  setup do
    # Start the supervisor with a unique name for test isolation
    name = :"execution_engine_#{:erlang.unique_integer([:positive])}"
    start_supervised!({ExecutionSupervisor, name: name})
    {:ok, supervisor: name}
  end

  describe "supervisor initialization" do
    test "starts with required child processes", %{supervisor: supervisor} do
      # Check that both the registry and dynamic supervisor are running
      assert Process.whereis(Module.concat(supervisor, Registry))
      assert Process.whereis(Module.concat(supervisor, ObjectiveSupervisor))
    end
  end

  describe "objective management" do
    setup do
      # Create a test objective
      {:ok, objective} = Objective.new(%{
        name: :test_objective,
        description: "Test objective",
        success_criteria: "Test completed",
        steps: ["Step 1", "Step 2"],
        input_schema: %{
          required: ["test_input"],
          properties: %{
            "test_input" => %{type: "string"}
          }
        }
      })

      # Create a mock company process
      company_pid = spawn_link(fn -> receive do _ -> :ok end end)

      {:ok, objective: objective, company_pid: company_pid}
    end

    test "starts an objective process", %{supervisor: supervisor, objective: objective, company_pid: company_pid} do
      assert {:ok, pid} = ExecutionSupervisor.start_objective(
        supervisor,
        objective,
        company_pid,
        %{"test_input" => "value"}
      )

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "stops an objective process", %{supervisor: supervisor, objective: objective, company_pid: company_pid} do
      objective_id = "objective_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ExecutionSupervisor.start_objective(
        supervisor,
        objective,
        company_pid,
        %{"test_input" => "value"},
        objective_id
      )

      assert :ok = ExecutionSupervisor.stop_objective(supervisor, objective_id)
      refute Process.alive?(pid)
    end

    test "lists running objectives", %{supervisor: supervisor, objective: objective, company_pid: company_pid} do
      assert [] = ExecutionSupervisor.list_objectives(supervisor)

      {:ok, _pid} = ExecutionSupervisor.start_objective(
        supervisor,
        objective,
        company_pid,
        %{"test_input" => "value"}
      )

      objectives = ExecutionSupervisor.list_objectives(supervisor)
      assert length(objectives) == 1
    end
  end
end

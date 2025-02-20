defmodule Lux.Company.ExecutionEngine.SupervisorTest do
  use UnitCase, async: true

  alias Lux.Company.ExecutionEngine.ArtifactStore
  alias Lux.Company.ExecutionEngine.Supervisor, as: ExecutionSupervisor
  alias Lux.Company.ExecutionEngine.TaskTracker
  alias Lux.Company.Objective

  setup do
    # Start the supervisor with a unique name for test isolation
    name = :"execution_engine_#{:erlang.unique_integer([:positive])}"
    start_supervised!({ExecutionSupervisor, name: name})
    {:ok, supervisor: name}
  end

  describe "supervisor initialization" do
    test "starts with required child processes", %{supervisor: supervisor} do
      # Check that all required processes are running
      assert Process.whereis(Module.concat(supervisor, Registry))
      assert Process.whereis(Module.concat(supervisor, ObjectiveSupervisor))
      assert Process.whereis(Module.concat(supervisor, ComponentSupervisor))
    end
  end

  describe "objective management" do
    setup do
      # Create a test objective
      {:ok, objective} =
        Objective.new(%{
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
      company_pid =
        spawn_link(fn ->
          receive do
            _ -> :ok
          end
        end)

      {:ok, objective: objective, company_pid: company_pid}
    end

    test "starts an objective process with components", %{
      supervisor: supervisor,
      objective: objective,
      company_pid: company_pid
    } do
      assert {:ok, pid} =
               ExecutionSupervisor.start_objective(
                 supervisor,
                 objective,
                 company_pid,
                 %{"test_input" => "value"}
               )

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Get the objective ID from the registry
      [{objective_pid, objective_id}] = Registry.lookup(Module.concat(supervisor, Registry), pid)

      # Verify task tracker is running
      task_registry = Module.concat(objective_id, TaskRegistry)
      assert Process.whereis(task_registry)
      assert [{task_tracker_pid, nil}] = Registry.lookup(task_registry, "task_tracker")
      assert Process.alive?(task_tracker_pid)

      # Verify artifact store is running
      artifact_registry = Module.concat(objective_id, ArtifactRegistry)
      assert Process.whereis(artifact_registry)
      assert [{artifact_store_pid, nil}] = Registry.lookup(artifact_registry, "artifact_store")
      assert Process.alive?(artifact_store_pid)

      # Test task tracker functionality
      assert {:ok, task_id} = TaskTracker.create_task(task_tracker_pid, "Step 1")
      assert {:ok, task} = TaskTracker.get_task(task_tracker_pid, task_id)
      assert task.step == "Step 1"

      # Test artifact store functionality
      assert {:ok, artifact_id} =
               ArtifactStore.store_artifact(
                 artifact_store_pid,
                 "test_artifact",
                 "test content",
                 "text/plain",
                 step_id: "Step 1",
                 task_id: task_id
               )

      assert {:ok, artifact} = ArtifactStore.get_artifact(artifact_store_pid, artifact_id)
      assert artifact.name == "test_artifact"
    end

    test "stops an objective process and its components", %{
      supervisor: supervisor,
      objective: objective,
      company_pid: company_pid
    } do
      objective_id = "objective_#{:erlang.unique_integer([:positive])}"

      {:ok, pid} =
        ExecutionSupervisor.start_objective(
          supervisor,
          objective,
          company_pid,
          %{"test_input" => "value"},
          objective_id
        )

      # Get component PIDs before stopping
      task_registry = Module.concat(objective_id, TaskRegistry)
      artifact_registry = Module.concat(objective_id, ArtifactRegistry)
      task_registry_pid = Process.whereis(task_registry)
      artifact_registry_pid = Process.whereis(artifact_registry)

      assert :ok = ExecutionSupervisor.stop_objective(supervisor, objective_id)

      # Verify all processes are stopped
      refute Process.alive?(pid)
      refute Process.alive?(task_registry_pid)
      refute Process.alive?(artifact_registry_pid)
    end

    test "lists running objectives", %{
      supervisor: supervisor,
      objective: objective,
      company_pid: company_pid
    } do
      assert [] = ExecutionSupervisor.list_objectives(supervisor)

      objective_id = "objective_#{:erlang.unique_integer([:positive])}"

      {:ok, _pid} =
        ExecutionSupervisor.start_objective(
          supervisor,
          objective,
          company_pid,
          %{"test_input" => "value"},
          objective_id
        )

      objectives = ExecutionSupervisor.list_objectives(supervisor)
      assert length(objectives) == 1
      assert hd(objectives) == objective_id
    end

    test "handles component startup failures", %{
      supervisor: supervisor,
      objective: objective,
      company_pid: company_pid
    } do
      # Mock a failure by starting with an invalid registry name
      objective_id = "invalid/objective/id"

      assert {:error, _} =
               ExecutionSupervisor.start_objective(
                 supervisor,
                 objective,
                 company_pid,
                 %{"test_input" => "value"},
                 objective_id
               )

      # Verify no processes were left running
      assert [] = ExecutionSupervisor.list_objectives(supervisor)
    end
  end
end

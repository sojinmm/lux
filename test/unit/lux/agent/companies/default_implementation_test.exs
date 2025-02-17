defmodule Lux.Agent.Companies.DefaultImplementationTest do
  use UnitCase, async: true

  alias Lux.Agent.Companies.SignalHandler.DefaultImplementation
  alias Lux.Schemas.Companies.PlanSignal
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  describe "signal routing" do
    setup do
      context = %{
        beams: [],
        lenses: [],
        prisms: []
      }

      task_signal = %Signal{
        id: "test-1",
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => "task-1",
          "objective_id" => "obj-1",
          "title" => "Test Task",
          "description" => "A test task",
          "status" => "pending"
        },
        sender: "test-sender"
      }

      %{context: context, task_signal: task_signal}
    end

    test "handles task update signal", %{context: context, task_signal: signal} do
      signal = %{signal | payload: Map.put(signal.payload, "type", "status_update")}
      assert {:ok, response} = DefaultImplementation.handle_task_update(signal, context)
      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "status_update"
      assert response.payload["status"] == "in_progress"
      assert response.recipient == signal.sender
    end

    test "handles unknown signal type", %{context: context, task_signal: signal} do
      signal = %{signal | payload: Map.put(signal.payload, "type", "unknown")}

      assert {:error, :unsupported_task_type} =
               DefaultImplementation.handle_signal(signal, context)
    end

    test "handles unknown schema", %{context: context, task_signal: signal} do
      signal = %{signal | schema_id: "unknown"}
      assert {:error, :unsupported_schema} = DefaultImplementation.handle_signal(signal, context)
    end
  end

  describe "plan signal handling" do
    setup do
      context = %{
        beams: [],
        lenses: [],
        prisms: []
      }

      plan_signal = %Signal{
        id: "test-2",
        schema_id: PlanSignal,
        payload: %{
          "type" => "evaluate",
          "plan_id" => "plan-1",
          "objective_id" => "obj-1",
          "title" => "Test Plan",
          "steps" => [
            %{
              "index" => 0,
              "description" => "First step",
              "status" => "pending"
            }
          ]
        },
        sender: "test-sender"
      }

      %{context: context, plan_signal: plan_signal}
    end

    test "handles plan evaluation signal", %{context: context, plan_signal: signal} do
      assert {:error, :not_implemented} =
               DefaultImplementation.handle_plan_evaluation(signal, context)
    end

    test "handles plan update signal", %{context: context, plan_signal: signal} do
      signal = %{
        signal
        | payload:
            Map.merge(signal.payload, %{
              "type" => "status_update",
              "context" => %{"progress" => 50}
            })
      }

      assert {:error, :not_implemented} =
               DefaultImplementation.handle_plan_update(signal, context)
    end

    test "handles plan completion signal", %{context: context, plan_signal: signal} do
      signal = %{
        signal
        | payload:
            Map.merge(signal.payload, %{
              "type" => "completion",
              "context" => %{"progress" => 100},
              "steps" => [
                %{
                  "index" => 0,
                  "description" => "First step",
                  "status" => "completed"
                }
              ]
            })
      }

      assert {:error, :not_implemented} =
               DefaultImplementation.handle_plan_completion(signal, context)
    end
  end
end

defmodule Lux.Schemas.TaskSignal do
  @moduledoc """
  Schema for task delegation signals between agents.
  """

  use Lux.SignalSchema,
    name: "task",
    version: "1.0.0",
    description: "Represents a task to be executed by an agent",
    schema: %{
      type: :object,
      properties: %{
        task: %{
          type: :string,
          description: "The task description"
        },
        context: %{
          type: :object,
          description: "The execution context including parameters and previous results",
          properties: %{
            params: %{type: :object},
            results: %{
              type: :array,
              items: %{type: :object}
            }
          },
          required: ["params", "results"]
        }
      },
      required: ["task", "context"]
    }
end

defmodule Lux.Schemas.Companies.PlanSignal do
  @moduledoc """
  Schema for plan execution signals used by the CEO.

  This schema defines the structure for:
  1. Plan evaluation requests
  2. Next step determination
  3. Plan status updates and completion
  """

  use Lux.SignalSchema,
    name: "plan",
    version: "1.0.0",
    description: "Represents plan execution and management signals",
    schema: %{
      type: :object,
      properties: %{
        type: %{
          type: :string,
          enum: ["evaluate", "next_step", "status_update", "completion"],
          description: "The type of plan signal"
        },
        plan_id: %{
          type: :string,
          description: "Unique identifier for the plan"
        },
        objective_id: %{
          type: :string,
          description: "ID of the objective this plan belongs to"
        },
        title: %{
          type: :string,
          description: "Title of the plan"
        },
        current_step: %{
          type: :object,
          properties: %{
            index: %{type: :integer},
            description: %{type: :string},
            status: %{
              type: :string,
              enum: ["pending", "in_progress", "completed", "failed"]
            },
            assigned_to: %{type: :string},
            result: %{
              type: :object,
              properties: %{
                success: %{type: :boolean},
                output: %{type: :string},
                error: %{type: :string}
              }
            }
          }
        },
        steps: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              index: %{type: :integer},
              description: %{type: :string},
              status: %{
                type: :string,
                enum: ["pending", "in_progress", "completed", "failed"]
              },
              assigned_to: %{type: :string},
              dependencies: %{
                type: :array,
                items: %{type: :integer},
                description: "Indices of steps that must be completed first"
              }
            }
          }
        },
        context: %{
          type: :object,
          properties: %{
            progress: %{
              type: :integer,
              minimum: 0,
              maximum: 100
            },
            available_agents: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  id: %{type: :string},
                  capabilities: %{
                    type: :array,
                    items: %{type: :string}
                  }
                }
              }
            },
            constraints: %{
              type: :array,
              items: %{type: :string}
            }
          }
        },
        evaluation: %{
          type: :object,
          properties: %{
            decision: %{
              type: :string,
              enum: ["continue", "adjust", "complete", "fail"]
            },
            next_step_index: %{type: :integer},
            assigned_agent: %{type: :string},
            adjustments: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  step_index: %{type: :integer},
                  change: %{type: :string}
                }
              }
            },
            reasoning: %{type: :string}
          }
        },
        metadata: %{
          type: :object,
          properties: %{
            started_at: %{type: :string, format: "date-time"},
            updated_at: %{type: :string, format: "date-time"},
            completed_at: %{type: :string, format: "date-time"}
          }
        }
      },
      required: ["type", "plan_id", "objective_id", "title"],
      additionalProperties: false
    },
    tags: ["plan", "workflow", "ceo"],
    compatibility: :full,
    format: :json
end

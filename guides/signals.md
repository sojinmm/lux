# Signals Guide

Signals are the fundamental units of communication in Lux. They provide a type-safe, schema-validated way for components to exchange information.

## Overview

A Signal consists of:
- A unique identifier
- A schema identifier that defines its structure
- Content that conforms to the schema
- Optional metadata and transformations

## Creating a Signal Schema

Signal schemas define the structure and validation rules for signals:

```elixir
defmodule MyApp.Schemas.TaskSchema do
  use Lux.SignalSchema,
    name: "task",
    version: "1.0.0",
    description: "Represents a task assignment",
    schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        priority: %{type: :string, enum: ["low", "medium", "high"]},
        due_date: %{type: :string, format: "date-time"},
        assignee: %{type: :string},
        tags: %{type: :array, items: %{type: :string}}
      },
      required: ["title", "priority", "assignee"]
    },
    tags: ["task", "workflow"],
    compatibility: :full,
    format: :json
end
```

## Creating a Signal

Signals are created by modules that use the `Lux.Signal` behaviour:

```elixir
defmodule MyApp.Signals.Task do
  use Lux.Signal,
    schema: MyApp.Schemas.TaskSchema

  # Optional: Validate the content before creating the signal
  def validate(%{title: title} = content) when byte_size(title) > 0 do
    {:ok, content}
  end
  def validate(_), do: {:error, "Title cannot be empty"}

  # Optional: Transform the content before creating the signal
  def transform(content) do
    {:ok,
     content
     |> Map.put_new_lazy(:due_date, &DateTime.utc_now/0)
     |> Map.update(:tags, [], &Enum.uniq/1)}
  end
end
```

## Using Signals

Signals can be created and used in various ways:

```elixir
# Create a new task signal
{:ok, signal} = MyApp.Signals.Task.new(%{
  title: "Review PR",
  priority: "high",
  assignee: "alice",
  tags: ["github", "code-review"]
})

# Access signal properties
signal.id          # Unique identifier
signal.schema_id   # Schema identifier
signal.content     # Validated and transformed content
```

## Schema Evolution

Lux supports schema evolution through versioning and compatibility levels:

- `:full` - New schema must be fully compatible with old schema
- `:backward` - New schema can read old data
- `:forward` - Old schema can read new data
- `:none` - No compatibility guarantees

Example of schema evolution:

```elixir
defmodule MyApp.Schemas.TaskSchemaV2 do
  use Lux.SignalSchema,
    name: "task",
    version: "2.0.0",
    description: "Task assignment with status tracking",
    schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        priority: %{type: :string, enum: ["low", "medium", "high"]},
        due_date: %{type: :string, format: "date-time"},
        assignee: %{type: :string},
        tags: %{type: :array, items: %{type: :string}},
        status: %{type: :string, enum: ["pending", "in_progress", "completed"]},
        progress: %{type: :integer, minimum: 0, maximum: 100}
      },
      required: ["title", "priority", "assignee", "status"]
    },
    compatibility: :backward,
    reference: "v1: MyApp.Schemas.TaskSchema"
end
```

## Best Practices

1. **Schema Design**
   - Use semantic versioning for schemas
   - Document schema changes
   - Consider backward compatibility
   - Use appropriate compatibility levels

2. **Validation**
   - Validate business rules in `validate/1`
   - Keep validations focused and specific
   - Return clear error messages

3. **Transformation**
   - Use `transform/1` for data normalization
   - Add computed or default values
   - Clean up or format data

4. **Testing**
   - Test schema validation
   - Test business rule validation
   - Test transformations
   - Test compatibility between versions

Example test:
```elixir
defmodule MyApp.Signals.TaskTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates valid task signal" do
      {:ok, signal} = MyApp.Signals.Task.new(%{
        title: "Test Task",
        priority: "high",
        assignee: "bob"
      })

      assert signal.content.title == "Test Task"
      assert signal.content.priority == "high"
      assert signal.content.assignee == "bob"
      assert signal.content.due_date # Auto-added by transform
    end

    test "validates title presence" do
      assert {:error, "Title cannot be empty"} = 
        MyApp.Signals.Task.new(%{priority: "high", assignee: "bob"})
    end
  end
end
```

## Advanced Topics

### Schema Documentation
Schemas can include rich documentation:

```elixir
defmodule MyApp.Schemas.DocumentedTaskSchema do
  use Lux.SignalSchema,
    name: "documented_task",
    version: "1.0.0",
    description: """
    Represents a task assignment in the system.
    Tasks are the basic unit of work assignment and tracking.
    """,
    schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "Short title describing the task",
          examples: ["Review PR #123", "Deploy to production"]
        },
        priority: %{
          type: :string,
          enum: ["low", "medium", "high"],
          description: "Task priority level",
          default: "medium"
        }
      }
    },
    tags: ["task", "workflow"],
    reference: "https://example.com/docs/task-schema"
end
```

### Custom Validation Rules

You can implement complex validation rules:

```elixir
defmodule MyApp.Signals.ComplexTask do
  use Lux.Signal,
    schema: MyApp.Schemas.TaskSchema

  def validate(%{due_date: due_date} = content) do
    with {:ok, parsed_date} <- DateTime.from_iso8601(due_date),
         :ok <- validate_future_date(parsed_date),
         :ok <- validate_working_hours(parsed_date) do
      {:ok, content}
    end
  end

  defp validate_future_date(date) do
    if DateTime.compare(date, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, "Due date must be in the future"}
    end
  end

  defp validate_working_hours(date) do
    if date.hour >= 9 and date.hour <= 17 do
      :ok
    else
      {:error, "Due date must be during working hours (9-17)"}
    end
  end
end
```

### Signal Metadata

You can extend signals with metadata:

```elixir
defmodule MyApp.Signals.MetadataTask do
  use Lux.Signal,
    schema: MyApp.Schemas.TaskSchema

  def transform(content) do
    {:ok,
     content
     |> Map.put(:created_at, DateTime.utc_now())
     |> Map.put(:created_by, get_current_user())
     |> Map.put(:version, 1)
     |> Map.put(:trace_id, get_trace_id())}
  end
end
``` 
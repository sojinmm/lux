# Role Management in Lux

In Lux, companies can be defined with vacant roles, allowing for dynamic agent assignment. This guide explains how to manage roles and assign agents to them.

## Defining Vacant Roles

When defining a company, you can specify roles without assigning agents to them:

```elixir
defmodule MyApp.Companies.BlogTeam do
  use Lux.Company

  company do
    name("Content Creation Lab")
    mission("Create high-quality content")

    has_ceo "Content Director" do
      goal("Direct content creation")
      can("plan")
      can("review")
      # No agent specified - vacant role
    end

    has_member "Writer" do
      goal("Create content")
      can("write")
      can("edit")
      # No agent specified - vacant role
    end
  end
end
```

## Managing Roles

### Listing Roles

To get information about all roles in a company:

```elixir
{:ok, roles} = Lux.Company.list_roles(MyApp.Companies.BlogTeam)
[ceo, writer] = roles

# Each role has:
# - id: Unique identifier
# - name: Human-readable name
# - type: :ceo or :member
# - capabilities: List of capabilities
# - agent: Currently assigned agent (nil if vacant)
```

### Getting Role Information

To get information about a specific role:

```elixir
{:ok, role} = Lux.Company.get_role(MyApp.Companies.BlogTeam, role_id)
```

## Assigning Agents

Agents can be assigned to roles in two ways:

### 1. Local Agents

For agents that run in the same BEAM VM:

```elixir
# Assign a local agent module
{:ok, updated_role} = Lux.Company.assign_agent(
  MyApp.Companies.BlogTeam,
  role_id,
  MyApp.Agents.CEO
)
```

### 2. Remote Agents

For agents running in different nodes or systems:

```elixir
# Assign a remote agent with its ID and hub
{:ok, updated_role} = Lux.Company.assign_agent(
  MyApp.Companies.BlogTeam,
  role_id,
  {"agent-123", RemoteHub}
)
```

## Running Plans with Vacant Roles

When running a plan, Lux checks if all required roles have agents assigned. If a required role is vacant:

1. The plan will fail with a `:missing_agent` error
2. The error message will indicate which role needs an agent

```elixir
# This will fail if required roles don't have agents
{:ok, plan_id} = Lux.Company.run_plan(
  MyApp.Companies.BlogTeam,
  :create_blog_post,
  %{"topic" => "AI"}
)

# You'll receive an error message
receive do
  {:plan_failed, ^plan_id, {:missing_agent, message}} ->
    IO.puts "Plan failed: #{message}"
end
```

## Best Practices

1. **Role Definition**
   - Define roles with clear, focused capabilities
   - Use descriptive names that reflect the role's purpose
   - Document the role's goal and responsibilities

2. **Agent Assignment**
   - Assign agents that match the role's capabilities
   - Consider using remote agents for specialized tasks
   - Validate agent capabilities before assignment

3. **Error Handling**
   - Check for `:missing_agent` errors when running plans
   - Provide clear feedback when agent assignment fails
   - Validate role IDs before attempting agent assignment

4. **Dynamic Role Management**
   - Consider implementing agent selection logic
   - Keep track of agent assignments
   - Monitor agent health and performance

## Example Workflow

Here's a complete example of managing roles and running a plan:

```elixir
# Start the company
{:ok, _pid} = Lux.Company.start_link(MyApp.Companies.BlogTeam)

# List all roles
{:ok, roles} = Lux.Company.list_roles(MyApp.Companies.BlogTeam)
[ceo, writer] = roles

# Assign agents to roles
{:ok, _} = Lux.Company.assign_agent(MyApp.Companies.BlogTeam, ceo.id, MyApp.Agents.CEO)
{:ok, _} = Lux.Company.assign_agent(MyApp.Companies.BlogTeam, writer.id, MyApp.Agents.Writer)

# Now the plan can run successfully
{:ok, plan_id} = Lux.Company.run_plan(
  MyApp.Companies.BlogTeam,
  :create_blog_post,
  %{"topic" => "AI"}
)

# Wait for completion
receive do
  {:plan_completed, ^plan_id, results} ->
    IO.puts "Plan completed successfully!"
end
``` 
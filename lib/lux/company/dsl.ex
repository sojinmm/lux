defmodule Lux.Company.DSL do
  @moduledoc """
  Provides the DSL for defining companies and their structure.

  ## Examples

      company do
        name("Test Company")
        mission("Testing")

        has_ceo "CEO" do
          goal("Lead the company")
          can("plan")
          can("review")
          # Local agent
          agent(TestCEO)
        end

        has_member "Remote Member" do
          goal("Do remote work")
          can("work")
          # Remote agent
          agent("agent-123", hub: RemoteHub)
        end
      end
  """

  defmacro company(do: block) do
    quote do
      @company_config %Lux.Company{
        id: Lux.UUID.generate(),
        name: nil,
        mission: nil,
        ceo: nil,
        members: [],
        plans: %{}
      }
      unquote(block)
    end
  end

  defmacro name(value) do
    quote do
      @company_config Map.put(@company_config, :name, unquote(value))
    end
  end

  defmacro mission(value) do
    quote do
      @company_config Map.put(@company_config, :mission, unquote(value))
    end
  end

  defmacro has_ceo(name, do: block) do
    quote do
      var!(current_role) = %Lux.Company.Role{
        type: :ceo,
        name: unquote(name),
        id: Lux.UUID.generate(),
        capabilities: []
      }

      unquote(block)
      @company_config Map.put(@company_config, :ceo, var!(current_role))
    end
  end

  defmacro has_member(name, do: block) do
    quote do
      var!(current_role) = %Lux.Company.Role{
        type: :member,
        name: unquote(name),
        id: Lux.UUID.generate(),
        capabilities: []
      }

      unquote(block)
      @company_config Map.update!(@company_config, :members, &(&1 ++ [var!(current_role)]))
    end
  end

  @doc """
  Specifies the agent for a role.

  Can be used in two ways:
  1. With a module for local agents: `agent(TestAgent)`
  2. With an ID and hub for remote agents: `agent("agent-123", hub: RemoteHub)`
  """
  defmacro agent({:__aliases__, _, _} = module) do
    quote do
      var!(current_role) = Map.put(var!(current_role), :agent, unquote(module))
    end
  end

  defmacro agent(id, opts) when is_binary(id) do
    quote do
      hub = Keyword.get(unquote(opts), :hub)
      var!(current_role) =
        var!(current_role)
        |> Map.put(:agent, {unquote(id), hub})
        |> Map.put(:hub, hub)
    end
  end

  defmacro goal(value) do
    quote do
      var!(current_role) = Map.put(var!(current_role), :goal, unquote(value))
    end
  end

  defmacro can(capability) do
    quote do
      var!(current_role) =
        Map.update!(
          var!(current_role),
          :capabilities,
          &[unquote(capability) | &1]
        )
    end
  end

  defmacro plan(name, do: block) do
    quote do
      var!(current_plan) = %Lux.Company.Plan{
        name: unquote(name),
        inputs: [],
        steps: []
      }

      unquote(block)

      @company_config Map.update!(
                        @company_config,
                        :plans,
                        &Map.put(&1, unquote(name), var!(current_plan))
                      )
    end
  end

  defmacro input(do: block) do
    quote do
      unquote(block)
    end
  end

  defmacro field(name) do
    quote do
      var!(current_plan) =
        Map.update!(
          var!(current_plan),
          :inputs,
          &[unquote(name) | &1]
        )
    end
  end

  defmacro steps(value) do
    quote do
      steps =
        unquote(value)
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      var!(current_plan) = Map.put(var!(current_plan), :steps, steps)
    end
  end
end

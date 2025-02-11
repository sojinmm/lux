defmodule Lux.Company.RoleManagementTest do
  use UnitCase, async: true

  alias Lux.Company
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
  end

  defmodule TestCompany do
    @moduledoc false
    use Lux.Company

    company do
      name("Test Company")
      mission("Testing role management")

      has_ceo "Test CEO" do
        goal("Direct testing activities")
        can("plan")
        can("review")
        # No agent specified - vacant role
      end

      has_member "Test Researcher" do
        goal("Research test cases")
        can("research")
        can("analyze")
        # No agent specified - vacant role
      end

      has_member "Test Writer" do
        goal("Write test content")
        can("write")
        can("edit")
        # No agent specified - vacant role
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

  describe "role management" do
    setup do
      test_id = System.unique_integer([:positive])
      router_name = :"signal_router_#{test_id}"
      hub_name = :"agent_hub_#{test_id}"
      company_name = :"test_company_#{test_id}"

      # Start router and hub
      start_supervised!({Router.Local, name: router_name})
      start_supervised!({AgentHub, name: hub_name})

      # Start the company with proper configuration
      {:ok, _pid} = Company.start_link(TestCompany, name: company_name, router: router_name, hub: hub_name)

      %{
        company: company_name,
        router: router_name,
        hub: hub_name
      }
    end

    test "lists roles in company", %{company: company} do
      {:ok, roles} = Company.list_roles(company)
      assert length(roles) == 3
      [ceo | members] = roles

      assert ceo.type == :ceo
      assert ceo.name == "Test CEO"
      assert ceo.agent == nil

      [researcher, writer] = members
      assert researcher.name == "Test Researcher"
      assert researcher.agent == nil
      assert writer.name == "Test Writer"
      assert writer.agent == nil
    end

    test "assigns local agent to role", %{company: company} do
      {:ok, [ceo | _]} = Company.list_roles(company)
      assert {:ok, updated_role} = Company.assign_agent(company, ceo.id, TestAgent)
      assert updated_role.agent == TestAgent

      # Verify the change persisted
      {:ok, role} = Company.get_role(company, ceo.id)
      assert role.agent == TestAgent
    end

    test "assigns remote agent to role", %{company: company, hub: hub} do
      {:ok, [_, researcher | _]} = Company.list_roles(company)
      agent_spec = {"remote-agent-123", hub}
      assert {:ok, updated_role} = Company.assign_agent(company, researcher.id, agent_spec)
      assert updated_role.agent == agent_spec
      assert updated_role.hub == hub

      # Verify the change persisted
      {:ok, role} = Company.get_role(company, researcher.id)
      assert role.agent == agent_spec
      assert role.hub == hub
    end

    test "fails to assign agent to non-existent role", %{company: company} do
      assert {:error, :role_not_found} = Company.assign_agent(company, "invalid-id", TestAgent)
    end

    test "fails to run plan with missing agents", %{company: company} do
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Company.run_plan(company, :test_plan, params)

      # The plan should fail because no agents are assigned
      assert_receive {:plan_failed, ^plan_id, {:missing_agent, _}}, 1000
    end

    test "runs plan after assigning agents", %{company: company, hub: hub} do
      # First assign agents to all roles
      {:ok, [ceo, researcher, writer]} = Company.list_roles(company)

      :ok = Company.assign_agent(company, ceo.id, TestAgent)
      :ok = Company.assign_agent(company, researcher.id, TestAgent)
      :ok = Company.assign_agent(company, writer.id, TestAgent)

      # Now run the plan
      params = %{"test_input" => "example"}
      {:ok, plan_id} = Company.run_plan(company, :test_plan, params)

      # The plan should complete successfully
      assert_receive {:plan_completed, ^plan_id, {:ok, results}}, 5000
      assert length(results.results) == 4
    end
  end
end

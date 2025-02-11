defmodule Lux.CompanyTest do
  use UnitCase, async: true

  alias Lux.Company.Role

  # Test agent modules
  defmodule TestCEO do
    @moduledoc false
    use Lux.Agent

    def new(_opts \\ %{}) do
      Lux.Agent.new(%{
        name: "Test CEO",
        description: "A test CEO agent",
        goal: "Help with testing",
        capabilities: ["plan", "review"]
      })
    end
  end

  defmodule TestResearcher do
    @moduledoc false
    use Lux.Agent

    def new(_opts \\ %{}) do
      Lux.Agent.new(%{
        name: "Test Researcher",
        description: "A test researcher agent",
        goal: "Research things",
        capabilities: ["research", "analyze"]
      })
    end
  end

  # Test company module
  defmodule TestCompany do
    @moduledoc false
    use Lux.Company

    company do
      name("Test Company")
      mission("Testing the company DSL")

      has_ceo "Test Director" do
        agent(TestCEO)
        goal("Direct testing activities")
        can("plan tests")
        can("review results")
      end

      has_member "Test Researcher" do
        agent(TestResearcher)
        goal("Research test cases")
        can("research topics")
        can("analyze results")
      end
    end

    plan :run_test do
      input do
        field("Test subject")
        field("Test parameters")
      end

      steps("""
      1. Research the test subject
      2. Design test cases
      3. Execute tests
      4. Analyze results
      """)
    end
  end

  describe "company definition" do
    test "defines company structure" do
      company = TestCompany.__company__()

      assert company.name == "Test Company"
      assert company.mission == "Testing the company DSL"

      # Check CEO
      assert company.ceo.type == :ceo
      assert company.ceo.name == "Test Director"
      assert company.ceo.agent_module == TestCEO
      assert company.ceo.goal == "Direct testing activities"
      assert "plan tests" in company.ceo.capabilities
      assert "review results" in company.ceo.capabilities

      # Check members
      assert [member] = company.members
      assert member.type == :member
      assert member.name == "Test Researcher"
      assert member.agent_module == TestResearcher
      assert member.goal == "Research test cases"
      assert "research topics" in member.capabilities
      assert "analyze results" in member.capabilities
    end

    test "defines plans" do
      company = TestCompany.__company__()

      assert %{run_test: plan} = company.plans
      assert plan.name == :run_test
      assert "Test subject" in plan.inputs
      assert "Test parameters" in plan.inputs

      assert length(plan.steps) == 4
      assert Enum.at(plan.steps, 0) == "1. Research the test subject"
      assert Enum.at(plan.steps, 3) == "4. Analyze results"
    end
  end

  describe "company validation" do
    test "validates roles" do
      company = TestCompany.__company__()

      assert {:ok, _} = Role.validate(company.ceo)
      assert {:ok, _} = Role.validate(hd(company.members))
    end

    test "validates plans" do
      company = TestCompany.__company__()
      plan = company.plans.run_test

      assert {:ok, _} = Lux.Company.Plan.validate(plan)
    end
  end
end

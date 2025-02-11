defmodule Lux.Company.DSLTest do
  use UnitCase, async: true

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
    use Lux.Company

    company do
      name("Test Company")
      mission("Testing the DSL")

      has_ceo "Local CEO" do
        goal("Test things")
        can("test")
        can("review")
        agent(TestAgent)
      end

      has_member "Remote Member" do
        goal("Remote work")
        can("remote")
        agent("remote-123", hub: RemoteHub)
      end

      has_member "Vacant Role" do
        goal("To be filled")
        can("something")
        # No agent specified
      end
    end
  end

  describe "company definition" do
    test "defines company with correct structure" do
      company = TestCompany.__company__()
      assert company.name == "Test Company"
      assert company.mission == "Testing the DSL"
    end

    test "defines CEO with local agent" do
      company = TestCompany.__company__()
      assert company.ceo.type == :ceo
      assert company.ceo.name == "Local CEO"
      assert company.ceo.agent == TestAgent
      assert company.ceo.goal == "Test things"
      assert "test" in company.ceo.capabilities
      assert "review" in company.ceo.capabilities
      assert is_binary(company.ceo.id)
    end

    test "defines member with remote agent" do
      company = TestCompany.__company__()
      [remote, _] = company.members
      assert remote.type == :member
      assert remote.name == "Remote Member"
      assert remote.agent == {"remote-123", RemoteHub}
      assert remote.hub == RemoteHub
      assert remote.goal == "Remote work"
      assert "remote" in remote.capabilities
      assert is_binary(remote.id)
    end

    test "defines member without agent" do
      company = TestCompany.__company__()
      [_, vacant] = company.members
      assert vacant.type == :member
      assert vacant.name == "Vacant Role"
      assert vacant.agent == nil
      assert vacant.goal == "To be filled"
      assert "something" in vacant.capabilities
      assert is_binary(vacant.id)
    end
  end
end

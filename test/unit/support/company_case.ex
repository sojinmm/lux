defmodule Lux.CompanyCase do
  @moduledoc """
  This module defines the test case to be used by
  company-related tests.
  """

  use ExUnit.CaseTemplate
  alias Lux.Company
  alias Lux.Company.Hub.Local

  using do
    quote do
      @moduletag :unit
      # Import helpers
      import Lux.CompanyCase

      # Alias common test modules
      alias Lux.Company
      alias Lux.Company.Hub
      alias Lux.Company.Hub.Local
    end
  end

  setup do
    # Start a local company hub for each test
    hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
    table_name = :"table_#{:erlang.unique_integer([:positive])}"

    start_supervised!({Local, name: hub_name, table_name: table_name})

    # Return the hub name so tests can use it
    {:ok, hub: hub_name}
  end

  @doc """
  Creates a test company struct for testing.
  """
  def create_test_company(name) do
    %Company{
      id: Lux.UUID.generate(),
      name: name,
      mission: "Test company mission",
      module: __MODULE__,
      ceo: %{
        id: Lux.UUID.generate(),
        type: :ceo,
        name: "Test CEO",
        goal: "Test company leadership",
        capabilities: ["plan", "review"],
        agent: nil,
        hub: nil
      },
      roles: [
        %{
          id: Lux.UUID.generate(),
          type: :member,
          name: "Test Member",
          goal: "Help with testing",
          capabilities: ["test", "verify"],
          agent: nil,
          hub: nil
        }
      ],
      objectives: [],
      plans: %{}
    }
  end
end

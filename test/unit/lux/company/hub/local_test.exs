defmodule Lux.Company.Hub.LocalTest do
  use Lux.CompanyCase

  require Logger

  describe "local hub implementation" do
    test "registers and retrieves a company", %{hub: hub} do
      company = create_test_company("Test Company")
      assert {:ok, company_id} = Local.register_company(company, hub)
      assert {:ok, retrieved} = Local.get_company(company_id, hub)
      assert retrieved.name == company.name
    end

    test "lists registered companies", %{hub: hub} do
      company1 = create_test_company("Company 1")
      company2 = create_test_company("Company 2")

      assert {:ok, id1} = Local.register_company(company1, hub)
      assert {:ok, id2} = Local.register_company(company2, hub)

      assert {:ok, companies} = Local.list_companies(hub)
      assert length(companies) == 2
      assert Enum.any?(companies, &(&1.id == id1))
      assert Enum.any?(companies, &(&1.id == id2))
    end

    test "deregisters a company", %{hub: hub} do
      company = create_test_company("Test Company")
      assert {:ok, company_id} = Local.register_company(company, hub)
      assert :ok = Local.deregister_company(company_id, hub)
      assert {:error, :not_found} = Local.get_company(company_id, hub)
    end

    test "handles company module registration", %{hub: hub} do
      defmodule TestCompany do
        @moduledoc false
        def __company__ do
          %Lux.Company{
            name: "Test Module Company",
            mission: "Testing module registration"
          }
        end
      end

      assert {:ok, company_id} = Local.register_company(TestCompany, hub)
      assert {:ok, company} = Local.get_company(company_id, hub)
      assert company.name == "Test Module Company"
      assert company.module == TestCompany
    end

    test "searches companies", %{hub: hub} do
      company1 = create_test_company("Search Company 1")
      company2 = create_test_company("Search Company 2")

      assert {:ok, _} = Local.register_company(company1, hub)
      assert {:ok, _} = Local.register_company(company2, hub)

      assert {:ok, results} = Local.search_companies("Search", hub)
      assert length(results) == 2
    end
  end
end

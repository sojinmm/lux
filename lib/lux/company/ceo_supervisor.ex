defmodule Lux.Company.CEOSupervisor do
  @moduledoc """
  Supervises the CEO agent within a company.
  """

  use Supervisor

  def start_link({role, opts}) do
    Supervisor.start_link(__MODULE__, {role, opts}, name: name_for(role))
  end

  @impl true
  def init({role, opts}) do
    children = [
      {role.agent_module, Map.put(opts, :role, role)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp name_for(role) do
    Module.concat(role.agent_module, "Supervisor")
  end
end

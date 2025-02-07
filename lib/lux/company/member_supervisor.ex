defmodule Lux.Company.MemberSupervisor do
  @moduledoc """
  Supervises member agents within a company.
  """

  use Supervisor

  def start_link({members, opts}) do
    Supervisor.start_link(__MODULE__, {members, opts}, name: __MODULE__)
  end

  @impl true
  def init({members, opts}) do
    children =
      Enum.map(members, fn role ->
        {role.agent_module, Map.put(opts, :role, role)}
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Lux.Company.MemberSupervisor do
  @moduledoc """
  Supervises member agents within a company.
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    opts = Map.new(opts)
    Logger.info("Starting MemberSupervisor with #{length(opts.members || [])} members")
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    members = opts.members || []
    Logger.debug("Initializing MemberSupervisor with #{length(members)} members")

    children = members
    |> Enum.filter(fn role ->
      case role.agent do
        nil ->
          Logger.debug("Skipping member #{inspect(role.name)} - no agent assigned")
          false
        module when is_atom(module) ->
          Logger.debug("Including local agent #{inspect(module)} for member #{inspect(role.name)}")
          true
        _ ->
          Logger.debug("Skipping remote agent for member #{inspect(role.name)}")
          false
      end
    end)
    |> Enum.map(fn role ->
      Logger.debug("Creating child spec for member #{inspect(role.name)} with agent #{inspect(role.agent)}")
      {role.agent, Map.put(opts, :role, role)}
    end)

    Logger.info("MemberSupervisor starting with #{length(children)} children")
    Supervisor.init(children, strategy: :one_for_one)
  end
end

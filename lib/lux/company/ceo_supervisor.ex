defmodule Lux.Company.CEOSupervisor do
  @moduledoc """
  Supervises the CEO agent within a company.
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    opts = Map.new(opts)
    name = name_for(opts.role)
    Logger.info("Starting CEOSupervisor for role: #{inspect(opts.role.name)} with name: #{inspect(name)}")
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    role = opts.role
    Logger.debug("Initializing CEOSupervisor with role: #{inspect(role)}")

    children = case role.agent do
      nil ->
        Logger.debug("No agent assigned to CEO role, skipping child processes")
        []
      module when is_atom(module) ->
        Logger.debug("Starting local agent #{inspect(module)} for CEO role")
        [{module, Map.put(opts, :role, role)}]
      _ ->
        Logger.debug("Remote agent specified for CEO role, skipping child processes")
        []
    end

    Logger.info("CEOSupervisor starting with #{length(children)} children")
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp name_for(role) do
    name = case role.agent do
      nil -> Module.concat(role.name |> String.replace(" ", "") |> String.to_atom(), "Supervisor")
      module when is_atom(module) -> Module.concat(module, "Supervisor")
      _ -> Module.concat(role.name |> String.replace(" ", "") |> String.to_atom(), "Supervisor")
    end
    Logger.debug("Generated supervisor name: #{inspect(name)} for role: #{inspect(role.name)}")
    name
  end
end

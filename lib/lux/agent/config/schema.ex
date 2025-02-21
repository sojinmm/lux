defmodule Lux.Agent.Config.Schema do
  @moduledoc """
  JSON schema for agent configuration, derived from Lux.Agent struct.
  """

  alias Lux.Agent

  # These are the fields that must be provided in the JSON config
  @required_fields ["id", "name", "description", "goal"]

  def schema do
    %{
      "type" => "object",
      "required" => @required_fields,
      "properties" => properties()
    }
  end

  defp properties do
    Agent.__struct__()
    |> Map.from_struct()
    |> Map.keys()
    |> Map.new(fn key ->
      {Atom.to_string(key), type_for_field(key)}
    end)
  end

  defp type_for_field(:id), do: %{"type" => "string"}
  defp type_for_field(:name), do: %{"type" => "string"}
  defp type_for_field(:description), do: %{"type" => "string"}
  defp type_for_field(:goal), do: %{"type" => "string"}
  defp type_for_field(:template), do: %{"type" => "string"}
  defp type_for_field(:template_opts), do: %{"type" => "object"}
  defp type_for_field(:module), do: %{"type" => "string"}
  defp type_for_field(:prisms), do: %{"type" => "array", "items" => %{"type" => "string"}}
  defp type_for_field(:beams), do: %{"type" => "array", "items" => %{"type" => "string"}}
  defp type_for_field(:lenses), do: %{"type" => "array", "items" => %{"type" => "string"}}

  defp type_for_field(:accepts_signals),
    do: %{"type" => "array", "items" => %{"type" => "string"}}

  defp type_for_field(:llm_config), do: %{"type" => "object"}
  defp type_for_field(:memory_config), do: %{"type" => ["object", "null"]}
  defp type_for_field(:memory_pid), do: %{"type" => "null"}

  defp type_for_field(:scheduled_actions),
    do: %{"type" => "array", "items" => %{"type" => "object"}}

  defp type_for_field(:signal_handlers),
    do: %{"type" => "array", "items" => %{"type" => "object"}}

  defp type_for_field(:metadata), do: %{"type" => "object"}
  defp type_for_field(_), do: %{"type" => "object"}
end

defmodule Lux.Agent.Generator do
  @moduledoc """
  Generates Elixir agent modules from Config structs.
  """

  alias Lux.Agent.Config

  @doc """
  Generates an Elixir module from a Config struct.
  """
  @spec generate(Config.t()) :: {:ok, module()} | {:error, term()}
  def generate(%Config{} = config) do
    with {:ok, module_name} <- validate_module_name(config.module) do
      quoted =
        quote do
          use Lux.Agent,
            id: unquote(config.id),
            name: unquote(config.name),
            description: unquote(config.description),
            goal: unquote(config.goal),
            template: unquote(config.template),
            template_opts: unquote(Macro.escape(config.template_opts)),
            prisms: unquote(Macro.escape(config.prisms)),
            beams: unquote(Macro.escape(config.beams)),
            lenses: unquote(Macro.escape(config.lenses)),
            signal_handlers: unquote(Macro.escape(config.signal_handlers)),
            llm_config: unquote(Macro.escape(config.llm_config))
        end

      Module.create(module_name, quoted, Macro.Env.location(__ENV__))
      {:ok, module_name}
    end
  end

  defp validate_module_name(nil), do: {:error, :missing_module_name}

  defp validate_module_name(name) when is_binary(name) do
    if String.starts_with?(name, "Elixir.") do
      {:ok, String.to_atom(name)}
    else
      {:ok, String.to_atom("Elixir." <> name)}
    end
  end

  defp validate_module_name(name) when is_atom(name), do: {:ok, name}
  defp validate_module_name(_), do: {:error, :invalid_module_name}
end

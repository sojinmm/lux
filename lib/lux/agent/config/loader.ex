defmodule Lux.Agent.Config.Loader do
  @moduledoc """
  Loads agent configurations from JSON files or directories.
  """

  alias Lux.Agent
  alias Lux.Agent.Config.Schema

  require Logger

  @doc """
  Loads agent configurations from a path.
  If path is a directory, loads all .json files in that directory.
  If path is a file, loads that specific file.

  Returns a list of initialized agents.
  """
  def load(path) do
    cond do
      File.dir?(path) -> load_directory(path)
      File.exists?(path) -> load_file(path)
      true -> {:error, :invalid_path}
    end
  end

  @doc """
  Loads and initializes all agents from a directory of JSON files.
  """
  def load_directory(path) do
    path
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.map(&Path.join(path, &1))
    |> Enum.reduce({:ok, []}, fn file, {:ok, agents} ->
      case load_file(file) do
        {:ok, agent} ->
          {:ok, [agent | agents]}

        {:error, reason} ->
          Logger.error("Failed to load agent from #{file}: #{inspect(reason)}")
          {:ok, agents}
      end
    end)
    |> case do
      {:ok, []} ->
        {:error, :no_valid_agents_found}

      {:ok, agents} ->
        {:ok, Enum.reverse(agents)}
    end
  end

  @doc """
  Loads and initializes an agent from a JSON file.
  """
  def load_file(path) do
    with {:ok, content} <- File.read(path),
         {:ok, json} <- Jason.decode(content),
         :ok <- validate(json),
         {:ok, agent} <- to_agent(json) do
      {:ok, agent}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, :invalid_json}

      error ->
        error
    end
  end

  @doc """
  Validates a JSON configuration against the schema.
  """
  def validate(config) when is_map(config) do
    schema = Schema.schema()

    with :ok <- validate_required_fields(config, schema["required"]) do
      validate_types(config, schema["properties"])
    end
  end

  @doc """
  Converts a validated configuration into a Lux.Agent struct.
  """
  def to_agent(config) when is_map(config) do
    agent =
      config
      |> atomize_keys()
      |> convert_modules()
      |> then(&struct(Agent, &1))

    {:ok, agent}
  end

  # Private Functions

  defp validate_required_fields(config, required) do
    missing = Enum.filter(required, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_types(config, properties) do
    invalid =
      Enum.filter(config, fn {key, value} ->
        case properties[key] do
          nil -> false
          schema -> not valid_type?(value, schema)
        end
      end)

    if Enum.empty?(invalid) do
      :ok
    else
      {:error, {:invalid_types, invalid}}
    end
  end

  defp valid_type?(value, %{"type" => types}) when is_list(types) do
    Enum.any?(types, fn type -> valid_type?(value, %{"type" => type}) end)
  end

  defp valid_type?(value, %{"type" => "string"}) when is_binary(value), do: true
  defp valid_type?(value, %{"type" => "array"}) when is_list(value), do: true
  defp valid_type?(value, %{"type" => "object"}) when is_map(value), do: true
  defp valid_type?(nil, %{"type" => "null"}), do: true
  defp valid_type?(_, _), do: false

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), atomize_value(v)} end)
  end

  defp atomize_value(value) when is_map(value), do: atomize_keys(value)
  defp atomize_value(value) when is_list(value), do: Enum.map(value, &atomize_value/1)
  defp atomize_value(value), do: value

  defp convert_modules(config) do
    config
    |> convert_module_field(:module)
    |> convert_module_list(:prisms)
    |> convert_module_list(:beams)
    |> convert_module_list(:lenses)
    |> convert_module_list(:accepts_signals)
    |> convert_memory_config()
  end

  defp convert_module_field(config, key) do
    case Map.get(config, key) do
      nil -> config
      module when is_binary(module) -> Map.put(config, key, String.to_atom(module))
      module when is_atom(module) -> config
    end
  end

  defp convert_module_list(config, key) do
    case Map.get(config, key) do
      nil ->
        config

      modules when is_list(modules) ->
        Map.put(config, key, Enum.map(modules, &to_module/1))
    end
  end

  defp convert_memory_config(config) do
    case Map.get(config, :memory_config) do
      nil ->
        config

      memory_config when is_map(memory_config) ->
        Map.put(config, :memory_config, %{
          backend: to_module(memory_config.backend),
          name: to_module(memory_config[:name])
        })
    end
  end

  defp to_module(nil), do: nil
  defp to_module(module) when is_atom(module), do: module
  defp to_module(module) when is_binary(module), do: String.to_atom(module)
end

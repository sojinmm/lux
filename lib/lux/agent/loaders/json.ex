defmodule Lux.Agent.Loaders.Json do
  @moduledoc """
  Handles loading agent configurations from JSON sources.
  """

  alias Lux.Agent.Config

  @doc """
  Loads an agent configuration from a JSON source.
  The source can be:
  - A JSON string
  - A path to a JSON file
  - A path to a directory containing JSON files (first .json file will be used)

  Returns `{:ok, config}` if successful, `{:error, reason}` otherwise.
  """
  @spec load(String.t()) :: {:ok, Config.t()} | {:error, term()}
  def load(source) when is_binary(source) do
    cond do
      String.starts_with?(source, "{") ->
        parse(source)

      File.dir?(source) ->
        load_from_directory(source)

      File.exists?(source) ->
        load_from_file(source)

      true ->
        {:error, :invalid_source}
    end
  end

  @doc """
  Parses a JSON string into a Config struct.
  Returns `{:ok, config}` if successful, `{:error, reason}` otherwise.
  """
  @spec parse(String.t()) :: {:ok, Config.t()} | {:error, term()}
  def parse(json) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json) do
      Config.new(data)
    end
  end

  # Private functions

  defp load_from_file(path) do
    path
    |> File.read!()
    |> parse()
  end

  defp load_from_directory(dir) do
    case Path.wildcard(Path.join(dir, "*.json")) do
      [] -> {:error, :no_json_files_found}
      [path | _] -> load_from_file(path)
    end
  end
end

defmodule Lux.Agent.Loaders.Json do
  @moduledoc """
  Handles loading agent configurations from JSON sources.
  """

  alias Lux.Agent.Config

  @doc """
  Loads agent configuration(s) from a JSON source.
  The source can be:
  - A JSON string
  - A path to a JSON file
  - A path to a directory containing JSON files
  - A list of JSON file paths

  Returns:
  - `{:ok, Config.t()}` for single JSON string/file
  - `{:ok, [Config.t()]}` for directory or list of files
  - `{:error, term()}` on failure
  """
  @spec load(String.t() | [String.t()]) :: {:ok, Config.t() | [Config.t()]} | {:error, term()}
  def load(sources) when is_list(sources) do
    results = Enum.map(sources, &load_file/1)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {[], _errors} -> {:error, :no_valid_configs_found}
      {valid, _errors} -> {:ok, Enum.map(valid, fn {:ok, config} -> config end)}
    end
  end

  def load(source) when is_binary(source) do
    cond_result =
      cond do
        String.starts_with?(source, "{") ->
          parse(source)

        File.dir?(source) ->
          load_from_directory(source)

        File.exists?(source) ->
          load_file(source)

        true ->
          {:error, :invalid_source}
      end

    wrap_if_ok(cond_result)
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

  defp load_file(path) do
    with {:ok, content} <- File.read(path),
         {:ok, config} <- parse(content) do
      {:ok, config}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      error -> error
    end
  end

  defp load_from_directory(dir) do
    case Path.wildcard(Path.join(dir, "*.json")) do
      [] -> {:error, :no_json_files_found}
      paths -> load(paths)
    end
  end

  defp wrap_if_ok({:ok, data}), do: {:ok, List.wrap(data)}
  defp wrap_if_ok(other), do: other
end

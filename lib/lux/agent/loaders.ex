defmodule Lux.Agent.Loaders do
  @moduledoc """
  Entry point for loading agent configurations from various sources.
  """

  alias Lux.Agent.Config
  alias Lux.Agent.Generator
  alias Lux.Agent.Loaders.Json, as: JsonLoader

  @doc """
  Creates an agent module from a JSON configuration.
  The source can be:
  - A JSON string: `~s({"id": "researcher", ...})`
  - A file path: `"agents/researcher.json"`
  - A directory path: `"agents/"` (loads first .json file found)

  ## Examples

      # Load from file
      {:ok, ResearchAgent} = Loaders.from_json("agents/researcher.json")

      # Load from directory
      {:ok, FirstAgent} = Loaders.from_json("agents/")

      # Load from JSON string
      json = ~s({
        "id": "researcher",
        "name": "Research Agent",
        "description": "Conducts research",
        "goal": "Research effectively",
        "module": "ResearchAgent"
      })
      {:ok, ResearchAgent} = Loaders.from_json(json)
  """
  @spec from_json(String.t()) :: {:ok, module()} | {:error, term()}
  def from_json(source) when is_binary(source) do
    with {:ok, config} <- JsonLoader.load(source) do
      Generator.generate(config)
    end
  end
end

defmodule Lux.LLM do
  @moduledoc """
  A module for interacting with LLMs. Defines the behaviours for LLMs and provides a default implementation.
  """

  defmodule Response do
    @moduledoc """
    A response from an LLM.
    """
    require Record

    Record.defrecord(:response, __MODULE__,
      content: nil,
      tool_calls: [],
      finish_reason: nil
    )

    @type t ::
            record(:response,
              content: String.t() | nil,
              tool_calls: [%{type: String.t(), name: String.t(), params: map()}],
              finish_reason: String.t() | nil
            )
  end

  @type prompt :: String.t()
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t()]
  @type options :: Keyword.t()

  @callback call(prompt(), tools(), options()) :: {:ok, Response.t()} | {:error, String.t()}

  @default_module Application.compile_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAI)

  defdelegate call(prompt, tools, options), to: @default_module
end

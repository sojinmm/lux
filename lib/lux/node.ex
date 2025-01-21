defmodule Lux.Node do
  @moduledoc """
  Provides functions for executing Node.js code with variable bindings.

  ## Examples

      iex> require Lux.Node
      iex> Lux.Node.node variables: %{x: 40, y: 2} do
      ...>   ~JS'''
      ...>   x + y
      ...>   '''
      ...> end
      42
  """

  @module_path Application.app_dir(:lux, "priv/node")

  def eval(code, opts \\ []) do
    NodeJS.call({"index.mjs", "evaluate"}, [code], opts)
  end

  def eval!(code, opts \\ []) do
    NodeJS.call!({"index.mjs", "evaluate"}, [code], opts)
  end

  def module_path, do: @module_path

  def child_spec(opts \\ []) do
    NodeJS.Supervisor.child_spec([path: module_path()] ++ opts)
  end

  # to handle `node variables: %{}, do: ~JS"x+y"`
  # defmacro node([{:variables, _}, {:do, {:sigil_JS, _, [{:<<>>, _, [code]}, []]}}]) do
  #   quote do
  #     Lux.Node.eval!(unquote(code), [])
  #   end
  # end

  defmacro node(opts, do: {:sigil_JS, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      Lux.Node.eval!(unquote(code), unquote(opts))
    end
  end

  defmacro sigil_JS({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end
end

defmodule Lux.Node do
  @moduledoc """
  Provides functions for executing Node.js code with variable bindings.

  ## Examples

      iex> require Lux.Node
      iex> Lux.Node.nodejs variables: %{x: 40, y: 2} do
      ...>   ~JS'''
      ...>   export const main = ({x, y}) => x + y
      ...>   '''
      ...> end
      42
  """

  @module_path Application.app_dir(:lux, "priv/node")

  def eval(code, opts \\ []) do
    {variables, opts} = Keyword.pop(opts, :variables, %{})
    do_eval(code, variables, opts, &NodeJS.call/3)
  end

  def eval!(code, opts \\ []) do
    {variables, opts} = Keyword.pop(opts, :variables, %{})
    do_eval(code, variables, opts, &NodeJS.call!/3)
  end

  def module_path, do: @module_path

  def child_spec(opts \\ []) do
    NodeJS.Supervisor.child_spec([path: module_path()] ++ opts)
  end

  defp do_eval(code, variables, opts, fun) do
    filename = create_file_name(code)

    with {:ok, node_modules_path} <- maybe_create_node_modules(),
         file_path = Path.join(node_modules_path, filename),
         :ok <- File.write(file_path, code) do
      fun.({file_path, "main"}, [variables], opts)
    else
      error -> error
    end
  end

  defp maybe_create_node_modules do
    node_modules = Path.join(@module_path, "node_modules/lux")

    unless File.exists?(node_modules) do
      File.mkdir_p(node_modules)
    end

    {:ok, node_modules}
  end

  defp create_file_name(code) do
    hash = :crypto.hash(:sha, code) |> Base.encode16(case: :lower)
    "#{hash}.mjs"
  end

  defmacro nodejs(opts \\ [], do: {:sigil_JS, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      Lux.Node.eval!(unquote(code), unquote(opts))
    end
  end

  defmacro sigil_JS({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end
end

defmodule Lux.Python do
  @moduledoc """
  Provides functions for executing Python code with variable bindings.

  ## Examples

      iex> Lux.Python.eval("x + y", variables: %{x: 1, y: 2})
      {:ok, 3}

      iex> Lux.Python.eval(\"\"\"
      ...> def factorial(n):
      ...>     if n <= 1:
      ...>         return 1
      ...>     return n * factorial(n - 1)
      ...> factorial(n)
      ...> \"\"\", variables: %{n: 5})
      {:ok, 120}
  """

  alias Venomous.SnakeArgs

  @type eval_option :: {:variables, map()}
  @type eval_options :: [eval_option()]

  @doc """
  Evaluates Python code with optional variable bindings.

  ## Options

    * `:variables` - A map of variables to bind in the Python context

  ## Examples

      iex> Lux.Python.eval("x * 2", variables: %{x: 21})
      {:ok, 42}

      iex> Lux.Python.eval("undefined_var")
      {:error, "NameError: name 'undefined_var' is not defined"}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    variables = Keyword.get(opts, :variables, %{})
    args = SnakeArgs.from_params(:"lux.eval", :execute, [code, variables])

    case Venomous.python(args) do
      {:error, error} -> {:error, to_string(error)}
      result when is_binary(result) -> {:ok, String.Chars.to_string(result)}
      result -> {:ok, result}
    end
  end

  @doc """
  Same as `eval/2` but raises on error.

  ## Examples

      iex> Lux.Python.eval!("x + y", variables: %{x: 1, y: 2})
      3

      iex> Lux.Python.eval!("undefined_var")
      ** (RuntimeError) Python execution error: NameError: name 'undefined_var' is not defined
  """
  @spec eval!(String.t(), eval_options()) :: term() | no_return()
  def eval!(code, opts \\ []) do
    case eval(code, opts) do
      {:ok, result} -> result
      {:error, error} -> raise "Python execution error: #{error}"
    end
  end
end

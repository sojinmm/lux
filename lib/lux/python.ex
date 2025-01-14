defmodule Lux.Python do
  @moduledoc """
  Provides functions for executing Python code with variable bindings.

  The ~PY sigil is used to write Python code directly in Elixir files.
  The content inside ~PY sigils is preserved by the Elixir formatter
  to maintain proper Python indentation and formatting.

  ## Examples

      iex> require Lux.Python
      iex> Lux.Python.python variables: %{x: 40, y: 2} do
      ...>   ~PY'''
      ...>   x + y
      ...>   '''
      ...> end
      42
  """

  alias Venomous.SnakeArgs

  @type eval_option ::
          {:variables, map()}
          | {:timeout, pos_integer()}

  @type eval_options :: [eval_option()]

  @doc """
  Evaluates Python code with optional variable bindings and other options.

  ## Options

    * `:variables` - A map of variables to bind in the Python context
    * `:timeout` - Timeout in milliseconds for Python execution

  ## Examples

      iex> Lux.Python.eval("x * 2", variables: %{x: 21})
      {:ok, 42}

      iex> Lux.Python.eval("os.getenv('TEST')", env: %{"TEST" => "value"})
      {:ok, "value"}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    variables = Keyword.get(opts, :variables, %{})
    timeout = Keyword.get(opts, :timeout)

    args = %SnakeArgs{
      module: :"lux.eval",
      func: :execute,
      args: [code, variables]
    }

    args = if timeout, do: Map.put(args, :timeout, timeout), else: args

    venomous_opts = [
      kill_on_exception: false
    ]

    venomous_opts =
      if timeout do
        [python_timeout: timeout] ++ venomous_opts
      else
        venomous_opts
      end

    case Venomous.python(args, venomous_opts) do
      {:error, error} -> {:error, to_string(error)}
      {:error, :timeout} -> {:error, "timeout"}
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

  @doc """
  A macro that enables writing Python code directly in Elixir with variable bindings.
  Python code must be wrapped in ~PY sigil to bypass Elixir syntax checking.

  ## Options
    * `:variables` - A map of variables to bind in the Python context
    * `:timeout` - Timeout in milliseconds for Python execution

  ## Examples

      iex> require Lux.Python
      iex> Lux.Python.python variables: %{x: 40, y: 2} do
      ...>   ~PY'''
      ...>   x + y
      ...>   '''
      ...> end
      42

      iex> require Lux.Python
      iex> Lux.Python.python do
      ...>   ~PY'''
      ...>   def factorial(n):
      ...>       if n <= 1:
      ...>           return 1
      ...>       return n * factorial(n - 1)
      ...>   factorial(5)
      ...>   '''
      ...> end
      120
  """
  defmacro python(opts \\ [], do: {:sigil_PY, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      variables = Keyword.get(unquote(opts), :variables, %{})
      timeout = Keyword.get(unquote(opts), :timeout)

      eval_opts =
        []
        |> Keyword.put(:variables, variables)
        |> Keyword.put_new_lazy(:timeout, fn -> timeout end)
        |> Enum.reject(fn {_, v} -> is_nil(v) end)

      Lux.Python.eval!(unquote(code), eval_opts)
    end
  end

  @doc false
  defmacro sigil_PY({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end
end

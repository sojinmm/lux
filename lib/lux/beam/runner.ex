defmodule Lux.Beam.Runner do
  @moduledoc """
  Executes beam definitions by running steps in sequence, parallel, or conditionally
  based on the beam's structure.
  """

  def run(beam, input, opts \\ []) do
    with :ok <- validate_input(beam, input) do
      initial_context = %{input: input}
      steps = Lux.Beam.steps(beam)

      case execute_steps(steps, initial_context) do
        {:ok, context} ->
          output = get_last_step_output(context)
          log = generate_execution_log(beam, context, opts[:specter], output)
          {:ok, output.result, log}

        {:error, error, context} ->
          log = generate_execution_log(beam, context, opts[:specter], nil)
          {:error, error, log}
      end
    end
  end

  defp validate_input(%Lux.Beam{input_schema: input_schema}, _input) do
    case input_schema do
      nil -> :ok
      _schema -> :ok
    end
  end

  # Handle composite steps
  defp execute_steps({:sequence, steps}, context) do
    steps
    |> List.flatten()
    |> Enum.reduce_while({:ok, context}, fn
      step, {:ok, acc_context} ->
        case execute_step(step, acc_context) do
          {:ok, new_context} -> {:cont, {:ok, new_context}}
          error -> {:halt, error}
        end
    end)
  end

  defp execute_steps({:parallel, steps}, context) do
    steps
    |> Task.async_stream(
      fn step -> execute_step(step, context) end,
      ordered: false,
      on_timeout: :kill_task
    )
    |> Enum.reduce_while({:ok, context}, fn
      {:ok, {:ok, step_context}}, {:ok, acc_context} ->
        # Merge contexts in order they complete
        merged_context = Map.merge(acc_context, step_context)
        {:cont, {:ok, merged_context}}

      {:ok, {:error, error, step_context}}, _acc ->
        {:halt, {:error, error, step_context}}

      # Skip crashed tasks
      {:exit, _}, acc ->
        {:cont, acc}
    end)
  end

  defp execute_steps({:branch, condition, branches}, context) do
    condition_result =
      case condition do
        {module, function} -> apply(module, function, [context])
        function when is_function(function, 1) -> function.(context)
      end

    case Enum.find(branches, fn {condition, _step} -> condition == condition_result end) do
      {_condition, steps} when is_list(steps) ->
        # Handle multiple steps in branch
        execute_steps({:sequence, steps}, context)

      {_condition, step} ->
        execute_step(step, context)

      nil ->
        {:error, :no_matching_branch, context}
    end
  end

  defp execute_steps(step, context) when not is_nil(step) do
    execute_step(step, context)
  end

  defp execute_step(%{id: id, module: module, params: params, opts: opts}, context) do
    resolved_params = resolve_params(params, context)

    try do
      case apply(module, :handler, [resolved_params, context]) do
        {:ok, result} ->
          {:ok, Map.put(context, id, %{input: resolved_params, result: result})}

        {:error, error} ->
          handle_step_error(id, module, resolved_params, opts, error, context)
      end
    rescue
      error ->
        handle_step_error(id, module, resolved_params, opts, error, context)
    end
  end

  defp handle_step_error(id, module, params, %{retries: retries} = opts, _error, context)
       when retries > 0 do
    Process.sleep(opts.retry_backoff)

    execute_step(
      %{
        id: id,
        module: module,
        params: params,
        opts: %{opts | retries: retries - 1}
      },
      context
    )
  end

  defp handle_step_error(id, _module, params, %{fallback: fallback} = _opts, error, context)
       when not is_nil(fallback) do
    case apply_fallback(fallback, %{error: error, context: context}) do
      {:continue, result} ->
        {:ok, Map.put(context, id, %{input: params, result: result})}
      {:stop, result} ->
        {:error, result, context}
    end
  end

  defp handle_step_error(_id, _module, _params, _opts, error, context) do
    {:error, error, context}
  end

  defp apply_fallback(fallback, params) when is_function(fallback, 1) do
    fallback.(params)
  end

  defp apply_fallback({fallback_module, function}, params) when is_list(fallback_module) do
    apply(fallback_module, function, [params])
  end

  defp apply_fallback(fallback, params) when is_atom(fallback) do
    apply(fallback, :handle_error, [params])
  end

  defp resolve_params(params, context) when is_map(params) do
    # If params is a map, construct a new map with resolved values
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      Map.put(acc, key, resolve_value(value, context))
    end)
  end

  defp resolve_params(value, context) do
    # If params is not a map, resolve it directly
    resolve_value(value, context)
  end

  # Handle access paths (must start with :input or :steps)
  defp resolve_value([root | _] = path, context) when root in [:input, :steps] do
    get_in(context, path)
  end

  # Handle all other values as literals
  defp resolve_value(value, _context), do: value

  defp get_last_step_output(context) do
    context
    |> Map.delete(:input)
    |> dbg()
    |> Enum.sort_by(fn {key, _} ->
      case Integer.parse(to_string(key)) do
        {num, _} -> num
        _ -> key
      end
    end)
    |> List.last()
    |> elem(1)
  end

  defp generate_execution_log(beam, context, specter, output) do
    case beam.generate_execution_log do
      true ->
        %{
          beam_id: beam.id,
          started_by: specter || "system",
          started_at: DateTime.utc_now(),
          completed_at: DateTime.utc_now(),
          status: if(output, do: :completed, else: :failed),
          input: context.input,
          output: output,
          steps: context
                 |> Map.delete(:input)
                 |> Enum.map(fn {id, %{input: input, result: result}} ->
                   %{
                     id: id,
                     status: :completed,
                     started_at: DateTime.utc_now(),
                     completed_at: DateTime.utc_now(),
                     input: input,
                     output: result,
                     error: nil
                   }
                 end)
        }

      false ->
        nil
    end
  end
end

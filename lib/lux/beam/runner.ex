defmodule Lux.Beam.Runner do
  @moduledoc """
  Executes beam definitions by running steps in sequence, parallel, or conditionally
  based on the beam's structure.
  """

  def run(beam, input, opts \\ []) do
    with :ok <- validate_input(beam, input) do
      execution_log = init_execution_log(beam, input, opts[:specter])
      steps = Lux.Beam.steps(beam)

      case execute_steps(steps, %{input: input}, execution_log) do
        {:ok, context, log} ->
          output = get_last_step_output(context)
          final_log = maybe_update_execution_log(log, :completed, output)
          {:ok, output, final_log}

        {:error, error, log} ->
          final_log = maybe_update_execution_log(log, :failed, nil)
          {:error, error, final_log}
      end
    end
  end

  defp validate_input(%Lux.Beam{input_schema: input_schema}, _input) do
    case input_schema do
      nil -> :ok
      _schema -> :ok
    end
  end

  defp init_execution_log(%Lux.Beam{id: id, generate_execution_log: true}, input, specter) do
    %{
      beam_id: id,
      started_by: specter || "system",
      started_at: DateTime.utc_now(),
      completed_at: nil,
      status: :running,
      input: input,
      output: nil,
      steps: []
    }
  end

  defp init_execution_log(_, _, _), do: nil

  # Handle composite steps
  defp execute_step({:sequence, steps}, context, log),
    do: execute_steps({:sequence, steps}, context, log)

  defp execute_step({:parallel, steps}, context, log),
    do: execute_steps({:parallel, steps}, context, log)

  defp execute_step({:branch, condition, branches}, context, log),
    do: execute_steps({:branch, condition, branches}, context, log)

  # Handle individual step
  defp execute_step(%{id: id, module: module, params: params, opts: opts}, context, log) do
    start_time = DateTime.utc_now()
    resolved_params = resolve_params(params, context)
    updated_log = maybe_add_step_log(log, init_step_log(id, resolved_params, start_time))

    try do
      case apply(module, :handler, [resolved_params, context]) do
        {:ok, result} ->
          final_log = maybe_update_step_log(updated_log, id, :completed, result)
          {:ok, Map.put(context, to_string(id), result), final_log}

        {:error, error} ->
          handle_step_error(id, module, params, opts, error, context, updated_log)
      end
    rescue
      error ->
        handle_step_error(id, module, params, opts, error, context, updated_log)
    end
  end

  defp handle_step_error(id, module, params, %{retries: retries} = opts, _error, context, log)
       when retries > 0 do
    Process.sleep(opts.retry_backoff)

    execute_step(
      %{
        id: id,
        module: module,
        params: params,
        opts: %{opts | retries: retries - 1}
      },
      context,
      log
    )
  end

  defp handle_step_error(id, _module, _params, %{fallback: fallback} = _opts, error, context, log)
       when not is_nil(fallback) do
    case apply_fallback(fallback, %{error: error, context: context}) do
      {:continue, result} ->
        final_log = maybe_update_step_log(log, id, :completed, result)
        {:ok, Map.put(context, to_string(id), result), final_log}

      {:stop, result} ->
        final_log = maybe_update_step_log(log, id, :failed, nil, error)
        {:error, result, final_log}
    end
  end

  defp handle_step_error(id, _module, _params, _opts, error, _context, log) do
    final_log = maybe_update_step_log(log, id, :failed, nil, error)
    {:error, error, final_log}
  end

  defp apply_fallback(fallback, params) when is_function(fallback, 1) do
    fallback.(params)
  end

  defp apply_fallback(fallback, params) when is_atom(fallback) do
    apply(fallback, :handle_error, [params])
  end

  defp maybe_update_execution_log(nil, _status, _output), do: nil

  defp maybe_update_execution_log(log, status, output) do
    %{log | status: status, completed_at: DateTime.utc_now(), output: output}
  end

  defp resolve_params(params, context) do
    Enum.reduce(params, %{}, fn
      {key, {:ref, ref_id}}, acc ->
        referenced_value = get_in(context, [ref_id, :value])
        Map.put(acc, key, referenced_value)

      {key, :value}, acc ->
        Map.put(acc, key, context.input.value)

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp init_step_log(id, input, start_time) do
    %{
      id: id,
      status: :running,
      started_at: start_time,
      completed_at: nil,
      input: input,
      output: nil,
      error: nil
    }
  end

  defp maybe_add_step_log(nil, _step_log), do: nil

  defp maybe_add_step_log(log, step_log) do
    Map.update!(log, :steps, fn steps ->
      if Enum.any?(steps, &(&1.id == step_log.id)) do
        steps
      else
        steps ++ [step_log]
      end
    end)
  end

  defp maybe_update_step_log(log, id, status, output, error \\ nil)
  defp maybe_update_step_log(nil, _id, _status, _output, _error), do: nil

  defp maybe_update_step_log(log, id, status, output, error) do
    Map.update!(log, :steps, fn steps ->
      Enum.map(steps, fn
        %{id: ^id} = step ->
          %{
            step
            | status: status,
              completed_at: DateTime.utc_now(),
              output: output,
              error: error,
              input: step.input
          }

        other ->
          other
      end)
    end)
  end

  defp execute_steps({:sequence, steps}, context, log) do
    steps
    |> List.flatten()
    |> Enum.reduce_while({:ok, context, log}, fn
      step, {:ok, acc_context, acc_log} ->
        case execute_step(step, acc_context, acc_log) do
          {:ok, new_context, new_log} ->
            {:cont, {:ok, new_context, new_log}}

          error ->
            {:halt, error}
        end
    end)
  end

  defp execute_steps({:parallel, steps}, context, log) do
    steps
    |> Task.async_stream(
      fn step -> execute_step(step, context, log) end,
      ordered: false,
      on_timeout: :kill_task
    )
    |> Enum.reduce_while({:ok, context, log}, fn
      {:ok, {:ok, step_context, step_log}}, {:ok, acc_context, acc_log} ->
        # Merge contexts in order they complete
        merged_context = Map.merge(acc_context, step_context)
        merged_log = merge_logs(acc_log, step_log)
        {:cont, {:ok, merged_context, merged_log}}

      {:ok, {:error, error, step_log}}, _acc ->
        {:halt, {:error, error, step_log}}

      # Skip crashed tasks
      {:exit, _}, acc ->
        {:cont, acc}
    end)
  end

  defp execute_steps({:branch, condition, branches}, context, log) do
    condition_result =
      case condition do
        {module, function} -> apply(module, function, [context])
        function when is_function(function, 1) -> function.(context)
      end

    case Enum.find(branches, fn {condition, _step} -> condition == condition_result end) do
      {_condition, steps} when is_list(steps) ->
        # Handle multiple steps in branch
        execute_steps({:sequence, steps}, context, log)

      {_condition, step} ->
        execute_step(step, context, log)

      nil ->
        {:error, :no_matching_branch, log}
    end
  end

  defp execute_steps(step, context, log) when not is_nil(step) do
    execute_step(step, context, log)
  end

  defp merge_logs(nil, log), do: log
  defp merge_logs(log, nil), do: log

  defp merge_logs(log1, log2) do
    # Merge steps, keeping only the first occurrence of each step ID
    merged_steps =
      Enum.reduce(log2.steps, log1.steps, fn step, acc ->
        case Enum.find_index(acc, &(&1.id == step.id)) do
          nil -> acc ++ [step]
          _ -> acc
        end
      end)

    %{log1 | steps: merged_steps}
  end

  defp get_last_step_output(context) do
    context
    |> Map.delete(:input)
    |> Enum.filter(fn {key, _} -> is_binary(key) end)
    |> Enum.sort_by(fn {key, _} ->
      case Integer.parse(key) do
        {num, _} -> num
        _ -> key
      end
    end)
    |> List.last()
    |> elem(1)
  end
end

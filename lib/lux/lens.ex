defmodule Lux.Lens do
  @moduledoc """
  Lenses are used to load data from a source and return it to the calling specter.

  Given a
  """
  use Lux.Types

  defstruct after_focus: nil,
            name: nil,
            url: nil,
            method: :get,
            params: %{},
            headers: [],
            auth: nil,
            description: "",
            schema: %{}

  @type t :: %__MODULE__{
          name: String.t(),
          url: String.t(),
          method: atom(),
          params: map(),
          headers: list(),
          after_focus: (any() -> any()),
          auth: map(),
          description: String.t(),
          schema: map()
        }

  defmacro __using__(_opts) do
    quote do
      alias Lux.Lens
    end
  end

  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      name: attrs[:name] || "",
      url: attrs[:url] || "",
      method: attrs[:method] || :get,
      params: attrs[:params] || %{},
      headers: attrs[:headers] || [],
      auth: attrs[:auth] || nil,
      description: attrs[:description] || "",
      after_focus: attrs[:after_focus] || nil,
      schema: attrs[:schema] || %{}
    }
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  def focus(%__MODULE__{
        auth: nil,
        url: url,
        method: method,
        params: params,
        headers: headers,
        after_focus: after_focus
      }) do
    after_focus = after_focus || fn body -> {:ok, body} end

    [url: url, headers: headers, max_retries: 2]
    |> Keyword.merge(Application.get_env(:lux, :req_options, []))
    |> Req.new()
    |> Req.request([method: method] ++ body_or_params(method, params))
    |> case do
      {:ok, %{status: 200, body: body}} ->
        after_focus.(body)

      {:ok, response} ->
        {:error, response.body}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, inspect(reason)}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  def authenticate(%__MODULE__{auth: %{type: :api_key, key: key}} = lens),
    do: update_headers(lens, [{"Authorization", "Bearer #{key}"}])

  def authenticate(
        %__MODULE__{auth: %{type: :basic, username: username, password: password}} = lens
      ),
      do:
        update_headers(lens, [
          {"Authorization", "Basic #{Base.encode64("#{username}:#{password}")}"}
        ])

  def authenticate(%__MODULE__{auth: %{type: :oauth, token: token}} = lens),
    do: update_headers(lens, [{"Authorization", "Bearer #{token}"}])

  def authenticate(%__MODULE__{auth: %{type: :custom, auth_function: func}} = lens),
    do: func.(lens)

  # Helper function to update headers
  defp update_headers(%__MODULE__{headers: headers} = lens, new_headers) do
    %__MODULE__{lens | headers: headers ++ new_headers}
  end

  defp body_or_params(:get, params), do: [params: params]
  defp body_or_params(_method, params), do: [json: params]
end

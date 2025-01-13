defmodule Lux.Lens do
  @moduledoc """
  Lenses are used to load data from a source and return it to the calling specter.

  Given a
  """

  require Record

  Record.defrecord(:lens,
    after_focus: nil,
    name: nil,
    url: nil,
    method: :get,
    params: %{},
    headers: [],
    auth: nil,
    description: "",
    schema: %{}
  )

  @type t ::
          record(:lens,
            name: String.t(),
            url: String.t(),
            method: atom(),
            params: map(),
            headers: list(),
            after_focus: (any() -> any()),
            auth: map(),
            description: String.t(),
            schema: map()
          )

  defmacro __using__(_opts) do
    quote do
      import Lux.Lens
    end
  end

  def new(atrs) when is_map(atrs) do
    lens(
      name: atrs[:name] || "",
      url: atrs[:url] || "",
      method: atrs[:method] || :get,
      params: atrs[:params] || %{},
      headers: atrs[:headers] || [],
      auth: atrs[:auth] || nil,
      description: atrs[:description] || "",
      after_focus: atrs[:after_focus] || nil,
      schema: atrs[:schema] || %{}
    )
  end

  def new(atrs) when is_list(atrs) do
    atrs |> Map.new() |> new()
  end

  def focus(
        lens(
          auth: nil,
          url: url,
          method: method,
          params: params,
          headers: headers,
          after_focus: after_focus
        )
      ) do
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

  def authenticate(lens(auth: %{:type => :api_key, :key => key}) = record),
    do: update_headers(record, [{"Authorization", "Bearer #{key}"}])

  def authenticate(
        lens(auth: %{:type => :basic, :username => username, :password => password}) = record
      ),
      do:
        update_headers(record, [
          {"Authorization", "Basic #{Base.encode64("#{username}:#{password}")}"}
        ])

  def authenticate(lens(auth: %{:type => :oauth, :token => token}) = record),
    do: update_headers(record, [{"Authorization", "Bearer #{token}"}])

  def authenticate(lens(auth: %{:type => :custom, :auth_function => func}) = record),
    do: func.(record)

  # Helper function to update headers
  defp update_headers(lens(headers: headers) = record, new_headers) do
    lens(record, headers: headers ++ new_headers)
  end

  defp body_or_params(:get, params), do: [params: params]
  defp body_or_params(_method, params), do: [json: params]
end

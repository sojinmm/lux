defmodule Lux.Lens do
  @moduledoc """
  Lenses are used to load data from a source and return it to the calling specter.

  ## Example

      defmodule MyApp.Lenses.WeatherLens do
        use Lux.Lens,
          name: "Weather API",
          description: "Fetches weather data from OpenWeather API",
          url: "https://api.openweathermap.org/data/2.5/weather",
          method: :get,
          schema: %{
            type: :object,
            properties: %{
              location: %{type: :string, description: "City name"},
              units: %{type: :string, description: "Temperature units (metric/imperial)"}
            }
          }

        # Optional: Define a custom after_focus function
        def after_focus(%{"main" => %{"temp" => temp}} = body) do
          {:ok, %{temperature: temp, raw_data: body}}
        end
      end
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

  @optional_callbacks after_focus: 1

  defmacro __using__(opts) do
    quote do
      @behaviour Lux.Lens
      alias Lux.Lens

      # Register compile-time attributes
      Module.register_attribute(__MODULE__, :lens_struct, persist: false)

      # Create the struct at compile time
      @lens_struct Lux.Lens.new(
                     name:
                       Keyword.get(
                         unquote(opts),
                         :name,
                         __MODULE__ |> Module.split() |> List.last()
                       ),
                     description: Keyword.get(unquote(opts), :description, ""),
                     url: Keyword.get(unquote(opts), :url),
                     method: Keyword.get(unquote(opts), :method, :get),
                     params: Keyword.get(unquote(opts), :params, %{}),
                     headers: Keyword.get(unquote(opts), :headers, []),
                     auth: Keyword.get(unquote(opts), :auth),
                     schema: Keyword.get(unquote(opts), :schema, %{}),
                     after_focus: &__MODULE__.after_focus/1
                   )

      @doc """
      Returns the Lens struct for this module.
      """
      def view do
        case function_exported?(__MODULE__, :after_focus, 1) do
          true -> %{@lens_struct | after_focus: &__MODULE__.after_focus/1}
          false -> @lens_struct
        end
      end

      @doc """
      Focuses the lens with the given input.
      """
      def focus(input \\ %{}) do
        __MODULE__.view()
        |> Map.update!(:params, &Map.merge(&1, input))
        |> Lux.Lens.focus()
      end
    end
  end

  @callback after_focus(response :: any()) :: {:ok, any()} | {:error, any()}

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

  def focus(%__MODULE__{auth: auth} = lens) when not is_nil(auth) do
    lens
    |> authenticate()
    |> focus()
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

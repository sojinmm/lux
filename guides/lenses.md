# Lenses Guide

Lenses provide a way to interact with external systems and APIs in a structured, composable way. They handle authentication, data transformation, and error handling for external integrations.

## Overview

A Lens consists of:
- A URL endpoint
- HTTP method and parameters
- Authentication configuration
- Schema validation
- Response transformation

## Creating a Lens

Here's a basic example of a Lens:

```elixir
defmodule MyApp.Lenses.WeatherAPI do
  use Lux.Lens,
    name: "OpenWeather API",
    description: "Fetches weather data from OpenWeather",
    url: "https://api.openweathermap.org/data/2.5/weather",
    method: :get,
    auth: %{type: :api_key, key: System.get_env("OPENWEATHER_API_KEY")},
    schema: %{
      type: :object,
      properties: %{
        city: %{type: :string},
        units: %{type: :string, enum: ["metric", "imperial"]}
      },
      required: ["city"]
    }

  def after_focus(%{"main" => %{"temp" => temp}} = response) do
    {:ok, %{
      temperature: temp,
      raw_data: response
    }}
  end
end
```

## Using Lenses

Lenses can be used directly or within Beams:

```elixir
# Direct usage
{:ok, weather} = MyApp.Lenses.WeatherAPI.focus(%{
  city: "London",
  units: "metric"
})

# Access results
weather.temperature  # 20.5
weather.raw_data    # Full API response
```

## Authentication Types

### API Key Authentication
```elixir
defmodule MyApp.Lenses.APIKeyAuth do
  use Lux.Lens,
    name: "API Key Example",
    url: "https://api.example.com/data",
    auth: %{
      type: :api_key,
      key: System.get_env("API_KEY"),
      header: "X-API-Key"  # Optional, defaults to "Authorization"
    }
end
```

### Basic Authentication
```elixir
defmodule MyApp.Lenses.BasicAuth do
  use Lux.Lens,
    name: "Basic Auth Example",
    url: "https://api.example.com/secure",
    auth: %{
      type: :basic,
      username: System.get_env("API_USER"),
      password: System.get_env("API_PASS")
    }
end
```

### OAuth Authentication
```elixir
defmodule MyApp.Lenses.OAuthExample do
  use Lux.Lens,
    name: "OAuth Example",
    url: "https://api.example.com/oauth",
    auth: %{
      type: :oauth,
      token: fn -> fetch_oauth_token() end
    }

  defp fetch_oauth_token do
    # Implementation to fetch/refresh OAuth token
    {:ok, "token"}
  end
end
```

### Custom Authentication
```elixir
defmodule MyApp.Lenses.CustomAuth do
  use Lux.Lens,
    name: "Custom Auth Example",
    url: "https://api.example.com/custom",
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.authenticate/1
    }

  def authenticate(lens) do
    # Add custom headers or modify request
    headers = [{"X-Custom-Auth", "value"}]
    %{lens | headers: headers}
  end
end
```

## Response Transformation

### Basic Transformation
```elixir
defmodule MyApp.Lenses.UserAPI do
  use Lux.Lens,
    name: "User API",
    url: "https://api.example.com/users"

  def after_focus(%{"data" => users}) do
    transformed = Enum.map(users, fn user ->
      %{
        id: user["id"],
        name: user["name"],
        email: user["email"]
      }
    end)
    {:ok, %{users: transformed}}
  end
end
```

### Error Handling
```elixir
defmodule MyApp.Lenses.RobustAPI do
  use Lux.Lens,
    name: "Robust API",
    url: "https://api.example.com/data"

  def after_focus(%{"error" => error}) do
    {:error, "API Error: #{error}"}
  end

  def after_focus(%{"data" => nil}) do
    {:error, "No data available"}
  end

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
```

## Best Practices

1. **Authentication**
   - Use environment variables for credentials
   - Implement token refresh for OAuth
   - Handle authentication errors gracefully
   - Use appropriate auth type for the API

2. **Error Handling**
   - Handle common HTTP errors
   - Transform API-specific errors
   - Provide meaningful error messages
   - Include request context in errors

3. **Response Transformation**
   - Clean and normalize data
   - Remove unnecessary fields
   - Convert types appropriately
   - Handle missing or null values

4. **Testing**
   - Mock HTTP requests
   - Test authentication
   - Test error cases
   - Test transformations

Example test:
```elixir
defmodule MyApp.Lenses.WeatherAPITest do
  use ExUnit.Case, async: true
  import Mox

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/1" do
    test "fetches weather data successfully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params == %{"city" => "London", "units" => "metric"}
        Req.Test.json(conn, %{
          "main" => %{"temp" => 20.5},
          "weather" => [%{"description" => "clear sky"}]
        })
      end)

      {:ok, result} = MyApp.Lenses.WeatherAPI.focus(%{
        city: "London",
        units: "metric"
      })

      assert result.temperature == 20.5
    end

    test "handles API errors" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"error" => "City not found"}, status: 404)
      end)

      assert {:error, _} = MyApp.Lenses.WeatherAPI.focus(%{
        city: "NonexistentCity",
        units: "metric"
      })
    end
  end
end
```

## Advanced Topics

### Rate Limiting
```elixir
defmodule MyApp.Lenses.RateLimitedAPI do
  use Lux.Lens,
    name: "Rate Limited API",
    url: "https://api.example.com/data",
    rate_limit: %{
      requests: 100,
      window: :timer.seconds(60)
    }

  def before_focus(_params, opts) do
    case check_rate_limit() do
      :ok -> {:ok, opts}
      :error -> {:error, "Rate limit exceeded"}
    end
  end

  defp check_rate_limit do
    # Implementation
    :ok
  end
end
```

### Caching
```elixir
defmodule MyApp.Lenses.CachedAPI do
  use Lux.Lens,
    name: "Cached API",
    url: "https://api.example.com/data",
    cache: %{
      ttl: :timer.minutes(5),
      key_fn: &__MODULE__.cache_key/1
    }

  def cache_key(params) do
    "cached_api:#{params.id}"
  end

  def before_focus(params, opts) do
    case Cachex.get(:api_cache, cache_key(params)) do
      {:ok, value} when not is_nil(value) ->
        {:ok, value}
      _ ->
        {:continue, opts}
    end
  end

  def after_focus(response) do
    {:ok, response}
  end
end
```

### Retry Logic
```elixir
defmodule MyApp.Lenses.RetryingAPI do
  use Lux.Lens,
    name: "Retrying API",
    url: "https://api.example.com/data",
    retry: %{
      max_attempts: 3,
      base_delay: 1000,
      max_delay: 5000,
      exponential: true
    }

  def should_retry?({:error, %{status: status}}) do
    status in [500, 502, 503, 504]
  end
  def should_retry?(_), do: false

  def after_focus(response) do
    {:ok, response}
  end
end
``` 
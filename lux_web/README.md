# LuxWeb

## Setup Options

### Option 1: Using Docker (Recommended)

This project includes Docker configuration for easy setup and consistent development environments.

#### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) (Docker Compose is included with Docker Desktop installations)

#### Getting Started with Docker

1. Make the setup scripts executable:
   ```bash
   chmod +x lux_web/docker-start.sh lux_web/docker-stop.sh
   ```

2. Start the PostgreSQL database:
   ```bash
   cd lux_web && ./docker-start.sh
   ```
   This script will:
   - Start a PostgreSQL container
   - Create necessary environment files
   - Wait for the database to be ready
   - Create and migrate the database

3. Start the Phoenix server:
   ```bash
   cd lux_web && mix phx.server
   ```
   Or run it in interactive mode:
   ```bash
   cd lux_web && iex -S mix phx.server
   ```

4. To stop all containers when you're done:
   ```bash
   cd lux_web && ./docker-stop.sh
   ```

### Option 2: Manual Setup

To start your Phoenix server without Docker:

1. Ensure you have PostgreSQL installed and running locally
2. Copy the example environment file:
   ```bash
   cp dev.envrc.example dev.envrc
   ```
3. Run `cd lux_web && mix deps.get` to install dependencies
4. Create and migrate your database with `cd lux_web && mix ecto.setup`
5. Start Phoenix endpoint with `cd lux_web && mix phx.server` or inside IEx with `cd lux_web && iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Environment Configuration

This project uses [dotenvy](https://hexdocs.pm/dotenvy/Dotenvy.html) for environment variable management. The following files are used:

- `dev.envrc` - Base environment variables for development
- `dev.override.envrc` - Local development overrides (not committed to git)
- `test.envrc` - Test environment variables
- `test.override.envrc` - Test environment overrides (not committed to git)

## Development

### Database Management

- Create database: `mix ecto.create`
- Run migrations: `mix ecto.migrate`
- Reset database: `mix ecto.reset`

### Testing

Run tests with:
```bash
mix test
```

## Production

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

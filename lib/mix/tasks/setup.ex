defmodule Mix.Tasks.Setup do
  @moduledoc """
  Sets up the project for local development.

  This task:
  1. Installs Elixir dependencies
  2. Ensures Poetry is installed and configured
  3. Installs Python dependencies

  ## Usage

      mix setup
  """
  use Mix.Task

  @shortdoc "Sets up the project for local development"
  @requirements []

  @default_poetry_paths [
    "~/.local/bin/poetry",
    "/usr/local/bin/poetry",
    "/opt/homebrew/bin/poetry"
  ]

  defp safe_cmd(cmd, args, opts) do
    try do
      System.cmd(cmd, args, opts)
    rescue
      e in ErlangError ->
        case e do
          %ErlangError{original: :enoent} -> {:error, :not_found}
          _ -> reraise e, __STACKTRACE__
        end
    end
  end

  @impl Mix.Task
  def run(opts \\ []) do
    poetry_paths = Keyword.get(opts, :poetry_paths, @default_poetry_paths)

    Mix.shell().info("\n==> Setting up Lux for development\n")

    # Step 1: Install Elixir dependencies
    Mix.shell().info("==> Installing Elixir dependencies...")

    case safe_cmd("mix", ["deps.get"], into: IO.stream()) do
      {:error, :not_found} ->
        Mix.raise("Could not find 'mix' command")

      {_, 0} ->
        :ok

      {output, _} ->
        Mix.raise("Failed to install dependencies: #{output}")
    end

    # Step 2: Check and setup Poetry
    Mix.shell().info("\n==> Checking Poetry installation...")

    case find_poetry(poetry_paths) do
      {:ok, poetry_path} ->
        Mix.shell().info("Found Poetry at: #{poetry_path}")
        install_python_deps(poetry_path)

      :error ->
        Mix.shell().error("Poetry not found")

        Mix.shell().error("""
        Please try manually:

        1. Install Poetry:
            curl -sSL https://install.python-poetry.org | python3 -

        2. Add to your PATH by adding this line to ~/.zshrc or ~/.bashrc:
            export PATH="$HOME/.local/bin:$PATH"

        3. Reload your shell:
            source ~/.zshrc  # or source ~/.bashrc

        Then run `mix setup` again.
        """)

        exit({:shutdown, 0})
    end

    Mix.shell().info("""
    \n==> Setup completed successfully! 🎉

    You can now:
    • Run tests:
        mix test              # Run Elixir tests
        mix python.test       # Run Python tests

    • Generate documentation:
        mix docs

    • Start development:
        iex -S mix
    """)
  end

  defp find_poetry(paths) do
    # Check common Poetry installation paths
    poetry_path =
      Enum.find(paths, fn path ->
        path = Path.expand(path)
        File.exists?(path)
      end)

    if poetry_path do
      {:ok, Path.expand(poetry_path)}
    else
      :error
    end
  end

  defp install_python_deps(poetry_path) do
    python_dir = Path.join(File.cwd!(), "priv/python")
    Mix.shell().info("\n==> Installing Python dependencies...")

    case safe_cmd(poetry_path, ["install"], cd: python_dir, stderr_to_stdout: true) do
      {:error, :not_found} ->
        Mix.shell().error("\nFailed to execute Poetry command")

        Mix.shell().error("""

        Try these steps to resolve the issue:
        1. Make sure Poetry is properly installed:
            poetry --version
        2. If needed, update Poetry:
            poetry self update
        3. Try clearing Poetry's cache:
            poetry cache clear . --all
        4. Run setup again:
            mix setup
        """)

        exit({:shutdown, 1})

      {output, 0} ->
        Mix.shell().info(output)

      {output, _} ->
        Mix.shell().error("\nFailed to install Python dependencies:\n\n#{output}")

        Mix.shell().error("""

        Try these steps to resolve the issue:
        1. Clear Poetry's cache:
            cd priv/python && poetry cache clear . --all
        2. Delete the poetry.lock file (if it exists):
            rm priv/python/poetry.lock
        3. Update Poetry itself:
            poetry self update
        4. Run setup again:
            mix setup

        If the issue persists, please check the error message above for specific dependency conflicts.
        You may need to manually resolve version conflicts in priv/python/pyproject.toml.
        """)

        exit({:shutdown, 1})
    end
  end
end

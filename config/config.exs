import Config

config :venomous, :snake_manager, %{
  # TTL whenever python process is inactive
  snake_ttl_minutes: 10,
  # Number of python workers that don't get cleared by SnakeManager
  perpetual_workers: 2,
  # Interval for killing python processes past their ttl while inactive
  cleaner_interval: 60_000,
  # Erlport python options
  python_opts: [
    module_paths: ["priv/python"],
    compressed: 0,
    packet_bytes: 4,
    # Use python3 command instead of full path
    python_executable: "python3"
  ]
}

config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4"

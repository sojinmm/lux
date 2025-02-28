import Config

# Erlport python options
config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4o"

config :venomous, :snake_manager, %{
  snake_ttl_minutes: 10,
  perpetual_workers: 2,
  # Interval for killing python processes past their ttl while inactive
  cleaner_interval: 60_000,
  python_opts: [
    module_paths: ["priv/python"],
    compressed: 0,
    packet_bytes: 4,
    # Use python3 command instead of full path
    python_executable: "python3"
  ]
}

# Configure Etherscan API key for examples
config :lux, :api_keys, [
  etherscan: System.get_env("ETHERSCAN_API_KEY") || "YourApiKeyToken",
  etherscan_pro: System.get_env("ETHERSCAN_API_KEY_PRO") == "true"
]

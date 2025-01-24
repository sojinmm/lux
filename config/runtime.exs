import Config
import Dotenvy

if config_env() == :test do
  source([
    "test.envrc",
    "test.override.envrc"
  ])
else
  source(["#{config_env()}.envrc", "#{config_env()}.override.envrc", System.get_env()])
end

if config_env() in [:dev, :test] do
  config :lux, :api_keys,
    alchemy: env!("ALCHEMY_API_KEY", :string!),
    openai: env!("OPENAI_API_KEY", :string!),
    openweather: env!("OPENWEATHER_API_KEY", :string!),
    integration_openai: env!("INTEGRATION_OPENAI_API_KEY", :string!, required: false),
    integration_openweather: env!("INTEGRATION_OPENWEATHER_API_KEY", :string!, required: false)
end

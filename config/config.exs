import Config

env_config = "config.#{Mix.env()}.exs"
if File.exists?("config/" <> env_config), do: import_config(env_config)

# Suppress debug logs during tests unless MIX_DEBUG=1 is set
if System.get_env("MIX_DEBUG") != "1" do
  Logger.configure(level: :warning)
end

ExUnit.start()

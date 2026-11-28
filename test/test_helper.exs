# Suppress debug logs during tests unless MIX_DEBUG=1 is set
if System.get_env("MIX_DEBUG") != "1" do
  Logger.configure(level: :warning)
end

{:ok, _} = Phoenix.PubSub.Supervisor.start_link(name: MishkaGervaz.Test.PubSub)
{:ok, _} = MishkaGervaz.Test.Web.Endpoint.start_link()

ExUnit.start()

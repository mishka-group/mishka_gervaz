import Config

config :ash, default_string_length_count: :codepoints

if config_env() == :test do
  config :mishka_gervaz, :gettext_backend, MishkaGervaz.Test.Gettext

  config :mishka_gervaz, MishkaGervaz.Test.Web.Endpoint,
    secret_key_base: String.duplicate("mishka-gervaz-test-secret", 3),
    live_view: [signing_salt: "mishka-gervaz-test"],
    server: false
end

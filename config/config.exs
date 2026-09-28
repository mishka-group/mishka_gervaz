import Config

config :ash, default_string_length_count: :codepoints

if config_env() == :test do
  config :mishka_gervaz, :gettext_backend, MishkaGervaz.Test.Gettext
end

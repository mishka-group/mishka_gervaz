defmodule MishkaGervaz.Gettext do
  @moduledoc """
  Default Gettext backend for MishkaGervaz.

  This provides pre-translated UI strings for table components like pagination,
  filters, actions, and states.

  ## Supported Languages

  - English (default)
  - Persian (fa)

  ## Using Your Own Gettext Backend

  Configure your application to use a custom Gettext backend:

      config :mishka_gervaz, :gettext_backend, MyAppWeb.Gettext

  Then copy the translation files from MishkaGervaz to your project's
  `priv/gettext` directory and customize as needed.
  """

  # Suppress Expo/Gettext opaque type warning (library issue, not our code)
  @dialyzer :no_opaque

  use Gettext.Backend, otp_app: :mishka_gervaz, priv: "priv/gettext"
end

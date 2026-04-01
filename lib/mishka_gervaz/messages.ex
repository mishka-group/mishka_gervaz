defmodule MishkaGervaz.Messages do
  @moduledoc """
  Provides Gettext macros with configurable backend support.

  This module allows using Gettext macros while supporting a configurable
  backend through the `:gettext_backend` option or application config.

  ## Configuration

  ### Option 1: Pass backend directly (recommended for gettext extraction)

      defmodule MyModule do
        use MishkaGervaz.Messages, backend: MishkaCmsCore.Gettext

        def my_function do
          dgettext("mishka_gervaz", "Load More")
        end
      end

  ### Option 2: Use application config (for runtime switching)

      config :mishka_gervaz, :gettext_backend, MyAppWeb.Gettext

  Then:

      defmodule MyModule do
        use MishkaGervaz.Messages

        def my_function do
          dgettext("mishka_gervaz", "Load More")
        end
      end

  ## Translation Domain

  All MishkaGervaz translations use the `mishka_gervaz` domain. Translation
  files should be placed at:

      priv/gettext/LOCALE/LC_MESSAGES/mishka_gervaz.po

  """

  @doc """
  Injects Gettext macros into the using module.

  ## Options

  - `:backend` - The Gettext backend module to use. If not provided,
    falls back to the `:gettext_backend` config or `MishkaGervaz.Gettext`.

  ## Usage

      # With explicit backend (recommended for extraction)
      use MishkaGervaz.Messages, backend: MyApp.Gettext

      # With config-based backend
      use MishkaGervaz.Messages
  """
  @default_backend Application.compile_env(:mishka_gervaz, :gettext_backend, MishkaGervaz.Gettext)

  defmacro __using__(opts) do
    default = @default_backend
    backend = Keyword.get(opts, :backend, default)

    quote do
      use Gettext, backend: unquote(backend)
    end
  end

  @doc """
  Gets the configured Gettext backend at runtime.

  Returns the user-configured backend or `MishkaGervaz.Gettext` as default.
  """
  def gettext_backend do
    Application.get_env(:mishka_gervaz, :gettext_backend, MishkaGervaz.Gettext)
  end
end

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

  All MishkaGervaz translations use the `mishka_gervaz` domain, except the messages a form field
  type refuses a value with, which use the `errors` domain. Translation files should be placed at:

      priv/gettext/LOCALE/LC_MESSAGES/mishka_gervaz.po
      priv/gettext/LOCALE/LC_MESSAGES/errors.po

  ## Strings from the DSL

  Every string a resource's `mishka_gervaz` DSL holds is translated when it is drawn, through
  `translate_text/1`: labels, placeholders, prompts, `{label, value}` option labels, confirm
  messages, empty and error states, notices, headers and footers. A function value is called as
  it is and is not translated again. Mark a string with `dgettext_noop("mishka_gervaz", "...")` so
  `mix gettext.extract` finds it.

  ## Work in another process

  A new process has no Gettext locale of its own. Run work whose result holds words through
  `start_async/4`, `assign_async/4` or `in_caller_locale/1` so it is translated in the locale of
  the process that started it.

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
  require Phoenix.LiveView

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

  @doc """
  Translates a string a resource declared in its `mishka_gervaz` DSL, in the locale of the process
  that draws it.

  A binary is looked up in the `mishka_gervaz` domain of `gettext_backend/0`: the translation when
  the current locale has one, the string itself otherwise. `nil` and every other value are
  returned unchanged, so a function or a number a DSL option held passes through. A string holding
  `%{...}` is returned as it is.

  A resource marks a string only its DSL holds with `dgettext_noop("mishka_gervaz", "...")`, which
  returns the English string; MishkaGervaz translates it each time it is drawn.

      label dgettext_noop("mishka_gervaz", "Heading")

  ## Examples

      iex> MishkaGervaz.Messages.translate_text("No translation for this")
      "No translation for this"

      iex> MishkaGervaz.Messages.translate_text(nil)
      nil
  """
  @spec translate_text(term()) :: term()
  def translate_text(""), do: ""

  def translate_text(text) when is_binary(text) do
    backend = gettext_backend()

    case backend.lgettext(Gettext.get_locale(backend), "mishka_gervaz", nil, text, %{}) do
      {:ok, translated} -> translated
      {:default, default} -> default
      {:missing_bindings, _incomplete, _missing} -> text
    end
  end

  def translate_text(other), do: other

  @doc """
  Wraps `fun`, of arity 0 or 1, to run in the Gettext locales of the process that calls this.

  Give the wrapped function to the work another process runs, such as `Task.async/1` or
  `Task.async_stream/3`: a new process starts with no locale of its own, so words it translates are
  otherwise in the default locale. The locale set with `Gettext.put_locale/1` and each one set with
  `Gettext.put_locale/2` are carried.

  ## Examples

      Gettext.put_locale(MyApp.Gettext, "fa")

      Task.async(MishkaGervaz.Messages.in_caller_locale(fn -> Gettext.get_locale(MyApp.Gettext) end))
      |> Task.await()
      #=> "fa"
  """
  @spec in_caller_locale((-> result) | (arg -> result)) :: (-> result) | (arg -> result)
        when result: term(), arg: term()
  def in_caller_locale(fun) when is_function(fun, 0) do
    locales = caller_locales()

    fn ->
      put_locales(locales)
      fun.()
    end
  end

  def in_caller_locale(fun) when is_function(fun, 1) do
    locales = caller_locales()

    fn arg ->
      put_locales(locales)
      fun.(arg)
    end
  end

  @doc """
  `Phoenix.LiveView.start_async/4`, with `fun` run in the caller's Gettext locales
  (`in_caller_locale/1`).

  Use it in place of `Phoenix.LiveView.start_async/4` wherever the result holds words a person
  reads.
  """
  @spec start_async(Phoenix.LiveView.Socket.t(), term(), (-> term()), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def start_async(socket, name, fun, opts \\ []) when is_function(fun, 0) do
    Phoenix.LiveView.start_async(socket, name, in_caller_locale(fun), opts)
  end

  @doc """
  `Phoenix.LiveView.assign_async/4`, with `fun` run in the caller's Gettext locales
  (`in_caller_locale/1`).
  """
  @spec assign_async(
          Phoenix.LiveView.Socket.t(),
          atom() | [atom()],
          (-> {:ok, map()} | {:error, term()}),
          keyword()
        ) :: Phoenix.LiveView.Socket.t()
  def assign_async(socket, keys, fun, opts \\ []) when is_function(fun, 0) do
    Phoenix.LiveView.assign_async(socket, keys, in_caller_locale(fun), opts)
  end

  defp caller_locales do
    for {key, locale} <- Process.get(), is_binary(locale), gettext_key?(key), do: {key, locale}
  end

  defp gettext_key?(Gettext), do: true

  defp gettext_key?(key) when is_atom(key) do
    Code.ensure_loaded?(key) and function_exported?(key, :__gettext__, 1)
  end

  defp gettext_key?(_key), do: false

  defp put_locales(locales) do
    Enum.each(locales, fn
      {Gettext, locale} -> Gettext.put_locale(locale)
      {backend, locale} -> Gettext.put_locale(backend, locale)
    end)
  end
end

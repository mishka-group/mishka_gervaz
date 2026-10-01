defmodule MishkaGervaz.Test.Gettext do
  @moduledoc """
  The Gettext backend of MishkaGervaz's own tests, configured as `:gettext_backend` in the test
  environment.

  It reads MishkaGervaz's English templates in `priv/gettext` and has no translation file of its
  own. For the locale `"fa"` it translates in code: a message the templates do not translate is
  returned interpolated and prefixed with `"[fa:<domain>] "`, `<domain>` being the Gettext domain
  that was asked, so a test reads which backend, locale and domain answered. A plural message is
  prefixed the same way, after Gettext picks its singular or plural form. A message with a
  `%{key}` placeholder its bindings do not fill gives `{:missing_bindings, ...}` as the default
  backend does. Any other locale is answered as the default backend answers it.

      Gettext.put_locale(MishkaGervaz.Test.Gettext, "fa")
      Gettext.dgettext(MishkaGervaz.Test.Gettext, "errors", "is required")
      #=> "[fa:errors] is required"
  """

  use Gettext.Backend, otp_app: :mishka_gervaz, priv: "priv/gettext"

  @locale "fa"

  def handle_missing_translation(@locale, domain, msgctxt, msgid, bindings) do
    @locale
    |> super(domain, msgctxt, msgid, bindings)
    |> mark(domain)
  end

  def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
    super(locale, domain, msgctxt, msgid, bindings)
  end

  def handle_missing_plural_translation(
        @locale,
        domain,
        msgctxt,
        msgid,
        msgid_plural,
        n,
        bindings
      ) do
    @locale
    |> super(domain, msgctxt, msgid, msgid_plural, n, bindings)
    |> mark(domain)
  end

  def handle_missing_plural_translation(
        locale,
        domain,
        msgctxt,
        msgid,
        msgid_plural,
        n,
        bindings
      ) do
    super(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
  end

  defp mark({:default, text}, domain), do: {:default, "[#{@locale}:#{domain}] " <> text}
  defp mark(missing_bindings, _domain), do: missing_bindings
end

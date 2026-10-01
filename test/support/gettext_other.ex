defmodule MishkaGervaz.Test.OtherGettext do
  @moduledoc """
  A second Gettext backend for the tests that switch `:gettext_backend` and read a string through
  it. It is `MishkaGervaz.Test.Gettext` with its own marker: for the locale `"fa"` a message the
  English templates in `priv/gettext` do not translate is returned interpolated and prefixed with
  `"[other:fa:<domain>] "`, so a test reads which of the two backends answered.

      Gettext.put_locale(MishkaGervaz.Test.OtherGettext, "fa")
      Gettext.dgettext(MishkaGervaz.Test.OtherGettext, "mishka_gervaz", "Heading")
      #=> "[other:fa:mishka_gervaz] Heading"
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

  defp mark({:default, text}, domain), do: {:default, "[other:#{@locale}:#{domain}] " <> text}
  defp mark(missing_bindings, _domain), do: missing_bindings
end

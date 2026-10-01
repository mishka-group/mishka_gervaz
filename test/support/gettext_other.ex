defmodule MishkaGervaz.Test.OtherGettext do
  @moduledoc """
  A second Gettext backend, for the tests that switch `:gettext_backend` and read a string through
  it. Its messages are in `test/support/gettext_other`: a Persian `mishka_gervaz` domain that words
  two of `MishkaGervaz.Test.Gettext`'s messages differently.
  """

  use Gettext.Backend, otp_app: :mishka_gervaz, priv: "test/support/gettext_other"
end

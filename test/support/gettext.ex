defmodule MishkaGervaz.Test.Gettext do
  @moduledoc """
  The Gettext backend of MishkaGervaz's own tests, configured as `:gettext_backend` in the test
  environment. Its messages are in `test/support/gettext`: Persian (`fa`) translations of the
  `mishka_gervaz` and `errors` domains, for the tests that read a message in another language.
  """

  use Gettext.Backend, otp_app: :mishka_gervaz, priv: "test/support/gettext"
end

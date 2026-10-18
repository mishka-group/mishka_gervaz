defmodule MishkaGervaz.Test.Web.Endpoint do
  @moduledoc """
  The endpoint `Phoenix.LiveViewTest` mounts the pages of `MishkaGervaz.Test.Web.Router` through.

  Started by `test/test_helper.exs`; `config/config.exs` gives it its keys in the test env only.
  """

  use Phoenix.Endpoint, otp_app: :mishka_gervaz

  @session_options [
    store: :cookie,
    key: "_mishka_gervaz_test",
    signing_salt: "mishka-gervaz-test"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug MishkaGervaz.Test.Web.Router
end

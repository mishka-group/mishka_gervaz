defmodule MishkaGervaz.Test.Web.Router do
  @moduledoc """
  The pages the LiveView tests open.

    * `/items` — `MishkaGervaz.Test.Web.TablePageLive` with a table that writes its state into the
      URL.
    * `/items/fixed` — the same page with `url_sync={false}`: the table reads the URL and never
      writes it.
  """

  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser

    live "/items", MishkaGervaz.Test.Web.TablePageLive, :writes_url
    live "/items/fixed", MishkaGervaz.Test.Web.TablePageLive, :keeps_url
  end
end

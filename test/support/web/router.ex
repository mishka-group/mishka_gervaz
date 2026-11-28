defmodule MishkaGervaz.Test.Web.Router do
  @moduledoc """
  The pages the LiveView tests open.

    * `/items` — `MishkaGervaz.Test.Web.TablePageLive` with a table that writes its state into the
      URL.
    * `/items/fixed` — the same page with `url_sync={false}`: the table reads the URL and never
      writes it.
    * `/feed` — the same page with a table of `MishkaGervaz.Test.Web.FeedItem`, which keeps no
      count, writing its page into the URL.
    * `/kept` — the same page with a table of `MishkaGervaz.Test.Web.KeptItem`, which keeps the rows
      it has loaded, writing its template and page into the URL.
    * `/offset` — the same page with a table of `MishkaGervaz.Test.Web.OffsetItem`, whose read has no
      keyset pagination, so Load more reads from an offset.
    * `/mixed` — the same page with a table of `MishkaGervaz.Test.Web.MixedItem`, with a filter of
      every type and everything a URL may carry synced to it.
    * `/shelf` — the same page with a table of `MishkaGervaz.Test.Web.ShelfItem`, whose rows open
      a path.
    * `/desk` — the same page with a table of `MishkaGervaz.Test.Web.DeskItem`, whose rows open in
      the table's drawer.
    * `/ledger` — the same page with a multi-tenant table of `MishkaGervaz.Test.Web.LedgerItem`,
      read by a master, or with `?site=<id>` by that site's admin.
    * `/orders` — `MishkaGervaz.Test.Web.ViewsPageLive`, a table and a named view of it on one page.
    * `/wizard` — `MishkaGervaz.Test.Web.FormPageLive`, a page with the wizard form of
      `MishkaGervaz.Test.Web.WizardItem`.
    * `/plans` — `MishkaGervaz.Test.Web.PlanPageLive`, a page with the form of
      `MishkaGervaz.Test.Web.PlanItem`.
    * `/plans/drawer` — the same page with the form in a drawer.
    * `/steps` — `MishkaGervaz.Test.Web.StepPageLive`, a page with the wizard of
      `MishkaGervaz.Test.Web.StepItem`, whose steps save.
    * `/toasts` — `MishkaGervaz.Test.Web.ToastPageLive`, a page that pushes toasts.
    * `/placed` — `MishkaGervaz.Test.Web.PlacedPageLive`, a page that places the groups of
      `MishkaGervaz.Test.Web.PlacedItem`'s form in its own cards.
    * `/rules` — `MishkaGervaz.Test.Web.RulePageLive`, a page with the form of
      `MishkaGervaz.Test.Web.RuleItem`, whose fields each carry a rule.
    * `/crates` — `MishkaGervaz.Test.Web.CratePageLive`, a page with the form of
      `MishkaGervaz.Test.Web.CrateItem`, whose upload takes a file of any type.
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
    live "/feed", MishkaGervaz.Test.Web.TablePageLive, :feed
    live "/plain", MishkaGervaz.Test.Web.TablePageLive, :plain
    live "/offset", MishkaGervaz.Test.Web.TablePageLive, :offset
    live "/kept", MishkaGervaz.Test.Web.TablePageLive, :kept
    live "/mixed", MishkaGervaz.Test.Web.TablePageLive, :mixed
    live "/shelf", MishkaGervaz.Test.Web.TablePageLive, :shelf
    live "/desk", MishkaGervaz.Test.Web.TablePageLive, :desk
    live "/ledger", MishkaGervaz.Test.Web.TablePageLive, :ledger
    live "/orders", MishkaGervaz.Test.Web.ViewsPageLive
    live "/wizard", MishkaGervaz.Test.Web.FormPageLive
    live "/plans", MishkaGervaz.Test.Web.PlanPageLive, :page
    live "/plans/drawer", MishkaGervaz.Test.Web.PlanPageLive, :drawer
    live "/steps", MishkaGervaz.Test.Web.StepPageLive
    live "/toasts", MishkaGervaz.Test.Web.ToastPageLive
    live "/placed", MishkaGervaz.Test.Web.PlacedPageLive
    live "/rules", MishkaGervaz.Test.Web.RulePageLive
    live "/crates", MishkaGervaz.Test.Web.CratePageLive
  end
end

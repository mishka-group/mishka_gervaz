defmodule MishkaGervaz.Table.Web.SiteColumnLiveTest do
  @moduledoc """
  The Site column of a multi-tenant table (`ui do type :site end`), driven the way a reader drives
  it (`MishkaGervaz.Test.Web.LedgerItem` on `MishkaGervaz.Test.Web.TablePageLive`'s `/ledger`).

  A master reads every site's rows, and the column names each row's site. A site's admin reads only
  that site's rows, and the column is not drawn. `Shared.across_tenants?/1` says which.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Web.{Branch, LedgerItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint

  setup do
    on_exit(fn ->
      LedgerItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
      Branch |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)

    north = Ash.create!(Branch, %{name: "North shop"})
    south = Ash.create!(Branch, %{name: "South shop"})
    entry = Ash.create!(LedgerItem, %{title: "Rent", site_id: north.id}, tenant: north.id)
    other = Ash.create!(LedgerItem, %{title: "Power", site_id: south.id}, tenant: south.id)

    %{north: north, south: south, entry: entry, other: other}
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp row(record), do: "#items_ledger_items-#{record.id}"

  test "a master's read across the sites names each row's site", ctx do
    view = open("/ledger")

    assert has_element?(view, "#items_ledger_items-thead", "Site")
    assert has_element?(view, ~s|#{row(ctx.entry)} [data-role="gervaz-site-cell"]|, "North shop")
    assert has_element?(view, ~s|#{row(ctx.other)} [data-role="gervaz-site-cell"]|, "South shop")
  end

  test "a site's admin reads only that site's rows, with no Site column", ctx do
    view = open("/ledger?site=#{ctx.north.id}")

    assert has_element?(view, row(ctx.entry))
    refute has_element?(view, row(ctx.other))
    refute has_element?(view, "#items_ledger_items-thead", "Site")
    refute has_element?(view, ~s|[data-role="gervaz-site-cell"]|)
  end

  test "across_tenants?/1 is true only for a multi-tenant table read without a tenant", ctx do
    master = State.init("ledger", LedgerItem, %{id: "m", site_id: nil})
    admin = State.init("ledger", LedgerItem, %{id: "a", site_id: ctx.north.id})
    plain = State.init("desk", MishkaGervaz.Test.Web.DeskItem, %{id: "m", site_id: nil})

    assert Shared.across_tenants?(master)
    refute Shared.across_tenants?(admin)
    refute Shared.across_tenants?(plain)
  end
end

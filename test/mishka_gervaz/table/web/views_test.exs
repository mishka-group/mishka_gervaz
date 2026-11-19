defmodule MishkaGervaz.Table.Web.ViewsTest do
  @moduledoc """
  Named table views: one resource declares its table and a `view :refunds` with other columns and a
  base filter, and a mount picks the view with `view={:refunds}`. The table itself is untouched;
  the view reads its rows through the same stream, async load and paging.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Resource.Info.Table, as: Info
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.ViewedOrder

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @master %{id: "master-1", site_id: nil, role: :admin}

  setup do
    on_exit(fn -> ViewedOrder |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    orders = [
      %{number: 1, customer: "Ada", total: 40},
      %{
        number: 2,
        customer: "Bo",
        total: 25,
        refunded: true,
        refund_reason: "Broken",
        amount_refunded: 25
      },
      %{
        number: 3,
        customer: "Cy",
        total: 90,
        refunded: true,
        refund_reason: "Late",
        amount_refunded: 30
      },
      %{
        number: 4,
        customer: "Di",
        total: 70,
        refunded: true,
        refund_reason: "Twice",
        amount_refunded: 70
      }
    ]

    %{orders: Enum.map(orders, &Ash.create!(ViewedOrder, &1))}
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/orders")
    render_async(view, @await)
    view
  end

  defp header(view, table) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("##{table}_viewed_orders_stream-thead")
    |> LazyHTML.text()
  end

  defp rows(view, table) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("##{table}_viewed_orders_stream > div")
    |> Enum.map(&LazyHTML.text/1)
  end

  describe "the config" do
    test "the view has its own columns and the table keeps its own" do
      assert Enum.map(Info.columns(ViewedOrder), & &1.name) == [:number, :customer, :total]

      assert Enum.map(Info.columns(ViewedOrder, :refunds), & &1.name) ==
               [:number, :refund_reason, :amount_refunded]

      assert %{filter: filter, columns: %{default_sort: [amount_refunded: :desc]}} =
               Info.view(ViewedOrder, :refunds)

      refute is_nil(filter)
      assert Info.view(ViewedOrder, :nothing) == nil
    end

    test "apply_view/2 builds the view's columns, sort and name into the state" do
      table = State.init("orders", ViewedOrder, @master)
      refunds = State.apply_view(table, :refunds)

      assert Enum.map(table.static.columns, & &1.name) == [:number, :customer, :total]
      assert table.static.view == nil

      assert Enum.map(refunds.static.columns, & &1.name) ==
               [:number, :refund_reason, :amount_refunded]

      assert refunds.static.view == :refunds
      assert refunds.sort_fields == [amount_refunded: :desc]
      assert refunds.static.sortable_columns == [:amount_refunded]
    end

    test "a view the resource does not declare is refused" do
      state = State.init("orders", ViewedOrder, @master)

      assert_raise ArgumentError, ~r/declares no table view :nothing/, fn ->
        State.apply_view(state, :nothing)
      end
    end
  end

  describe "on a page" do
    test "two views of one resource draw different columns" do
      view = open()

      orders = header(view, "orders")
      refunds = header(view, "refunds")

      assert orders =~ "Customer"
      assert orders =~ "Total"
      refute orders =~ "Refund reason"

      assert refunds =~ "Refund reason"
      assert refunds =~ "Refunded"
      refute refunds =~ "Customer"
    end

    test "the view reads only the rows its filter keeps, in its own sort, page by page" do
      view = open()

      assert [first, second] = rows(view, "refunds")
      assert first =~ "Twice"
      assert second =~ "Late"

      view |> element(~s|#refunds [phx-click="next_page"]|) |> render_click()
      render_async(view, @await)

      assert [third] = rows(view, "refunds")
      assert third =~ "Broken"
    end

    test "the table itself still reads every row" do
      view = open()

      assert [first, second] = rows(view, "orders")
      assert first =~ "Ada"
      assert second =~ "Bo"
    end
  end
end

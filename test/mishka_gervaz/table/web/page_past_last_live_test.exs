defmodule MishkaGervaz.Table.Web.PagePastLastLiveTest do
  @moduledoc """
  A table opened at a page past its last one, as `?<prefix>_page=999` or a stale link opens it, on
  a numbered table and on a Load more one. The table says the page has no rows and offers a button
  back to page 1, which reads page 1 and writes it to the URL. A table with rows on its page, and an
  empty table on its first page, show neither.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{GatedItem, PlainItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @no_rows "No rows on this page"

  setup do
    on_exit(fn ->
      for resource <- [GatedItem, PlainItem] do
        resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
      end
    end)

    :ok
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp back_to_first_page(view) do
    view |> element("#items button", "Go to page 1") |> render_click()
    render_async(view, @await)
  end

  defp shown(view, resource, stream) do
    for item <- Ash.read!(resource),
        has_element?(view, "#items_#{stream}-#{item.id}"),
        do: item.title
  end

  test "a numbered table says the page has no rows and goes back to page 1" do
    Enum.each(~w(a b), &Ash.create!(GatedItem, %{title: &1, status: "draft"}))

    view = open("/items?page=999")
    assert render(view) =~ @no_rows
    assert shown(view, GatedItem, "gated_items") == []

    back_to_first_page(view)
    assert_patch(view, "/items")
    refute render(view) =~ @no_rows
    assert Enum.sort(shown(view, GatedItem, "gated_items")) == ~w(a b)
  end

  test "a Load more table says the page has no rows and goes back to page 1" do
    Enum.each(~w(a b c d e), &Ash.create!(PlainItem, %{title: &1}))

    view = open("/plain?page=9")
    assert render(view) =~ @no_rows
    refute has_element?(view, "#items button[phx-click=load_more]")

    back_to_first_page(view)
    assert_patch(view, "/plain")
    refute render(view) =~ @no_rows
    assert Enum.sort(shown(view, PlainItem, "plain_items")) == ~w(a b c d)
    assert has_element?(view, "#items button[phx-click=load_more]")
  end

  test "a page with rows says nothing of the kind" do
    Enum.each(~w(a b c d e), &Ash.create!(PlainItem, %{title: &1}))

    view = open("/plain?page=2")
    refute render(view) =~ @no_rows
    assert shown(view, PlainItem, "plain_items") == ~w(e)
  end

  test "a Load more that reads no row keeps the rows shown" do
    Enum.each(~w(a b c d e), &Ash.create!(PlainItem, %{title: &1}))
    view = open("/plain")

    PlainItem |> Ash.read!() |> Enum.find(&(&1.title == "e")) |> Ash.destroy!()
    view |> element("#items button[phx-click=load_more]") |> render_click()
    render_async(view, @await)

    refute render(view) =~ @no_rows
    assert Enum.sort(shown(view, PlainItem, "plain_items")) == ~w(a b c d)
  end

  test "an empty table on its first page shows its own empty state" do
    view = open("/items")
    refute render(view) =~ @no_rows
    assert render(view) =~ "No records found"
  end
end

defmodule MishkaGervaz.UIAdapters.TailwindToastTest do
  @moduledoc """
  The default adapter's `toast/1`: one dark note with a dot in its tone's colour, its sentence, an
  Undo button and a link when it has them, and a Close. Its buttons send their events with the
  toast's id; a link goes inside the app (`navigate`) or anywhere (`href`, as for a file).
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.UIAdapters.Tailwind

  defp render(assigns) do
    %{__changed__: nil, id: "toast-7", toast_id: 7, tone: :ok, text: "Order refunded."}
    |> Map.merge(assigns)
    |> Tailwind.toast()
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp one(doc, selector), do: LazyHTML.query(doc, selector)
  defp attr(doc, selector, name), do: doc |> one(selector) |> LazyHTML.attribute(name)
  defp text(doc, selector), do: doc |> one(selector) |> LazyHTML.text() |> String.trim()

  test "is a status note with its sentence, in its tone" do
    doc = render(%{tone: :warn})

    assert attr(doc, "#toast-7", "role") == ["status"]
    assert attr(doc, "#toast-7", "data-tone") == ["warn"]
    assert text(doc, ~s|[data-role="gervaz-toast-text"]|) == "Order refunded."
  end

  test "its Close sends on_close with the toast's id" do
    doc = render(%{})

    assert attr(doc, ~s|[data-role="gervaz-toast-close"]|, "phx-click") == ["gervaz_toast_close"]
    assert attr(doc, ~s|[data-role="gervaz-toast-close"]|, "phx-value-id") == ["7"]
    assert attr(doc, ~s|[data-role="gervaz-toast-close"]|, "aria-label") == ["Close"]
  end

  test "draws an Undo button only when it has one" do
    assert one(render(%{}), ~s|[data-role="gervaz-toast-undo"]|) |> Enum.count() == 0

    doc = render(%{undo_label: "Undo"})

    assert text(doc, ~s|[data-role="gervaz-toast-undo"]|) == "Undo"
    assert attr(doc, ~s|[data-role="gervaz-toast-undo"]|, "phx-click") == ["gervaz_toast_undo"]
    assert attr(doc, ~s|[data-role="gervaz-toast-undo"]|, "phx-value-id") == ["7"]
  end

  test "draws a link inside the app, or a plain address" do
    inside = render(%{navigate: "/admin/refunds", link_label: "See refunds"})

    assert attr(inside, ~s|[data-role="gervaz-toast-link"]|, "href") == ["/admin/refunds"]
    assert attr(inside, ~s|[data-role="gervaz-toast-link"]|, "data-phx-link") == ["redirect"]
    assert text(inside, ~s|[data-role="gervaz-toast-link"]|) == "See refunds"

    file = render(%{href: "/exports/orders.csv", link_label: "Download"})

    assert attr(file, ~s|[data-role="gervaz-toast-link"]|, "href") == ["/exports/orders.csv"]
    assert attr(file, ~s|[data-role="gervaz-toast-link"]|, "data-phx-link") == []
  end
end

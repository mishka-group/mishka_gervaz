defmodule MishkaGervaz.UIAdapters.TailwindSkeletonTest do
  @moduledoc """
  The default adapter's `skeleton/1`: placeholder rows or a placeholder block that hold the room of
  what they stand in for while it loads, marked busy for a screen reader, which hears "Loading…".
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.UIAdapters.Tailwind

  defp render(assigns) do
    %{__changed__: nil}
    |> Map.merge(assigns)
    |> Tailwind.skeleton()
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp one(doc, selector), do: LazyHTML.query(doc, selector)
  defp attr(doc, selector, name), do: doc |> one(selector) |> LazyHTML.attribute(name)

  test "draws as many placeholder rows as it is given, each the height of a row" do
    doc = render(%{rows: 7})

    assert attr(doc, ~s|[data-role="gervaz-skeleton"]|, "aria-busy") == ["true"]
    assert attr(doc, ~s|[data-role="gervaz-skeleton"]|, "data-rows") == ["7"]
    assert one(doc, ~s|[data-role="gervaz-skeleton-row"]|) |> Enum.count() == 7
    assert doc |> one(".sr-only") |> LazyHTML.text() =~ "Loading"
  end

  test "draws five rows when not told how many, and a row's class replaces its height" do
    doc = render(%{row_class: "h-[72px]"})

    rows = one(doc, ~s|[data-role="gervaz-skeleton-row"]|)
    assert Enum.count(rows) == 5
    assert rows |> LazyHTML.attribute("class") |> Enum.all?(&(&1 =~ "h-[72px]"))
  end

  test "a block holds its height and draws its lines" do
    doc = render(%{type: :block, lines: 3, class: "h-[180px]"})

    assert attr(doc, ~s|[data-role="gervaz-skeleton"]|, "data-type") == ["block"]
    assert attr(doc, ~s|[data-role="gervaz-skeleton"]|, "class") |> hd() =~ "h-[180px]"
    assert one(doc, ~s|[data-role="gervaz-skeleton-line"]|) |> Enum.count() == 3
  end
end

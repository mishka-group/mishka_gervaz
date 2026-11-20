defmodule MishkaGervaz.UIAdapters.TailwindDrawerTest do
  @moduledoc """
  The default adapter's `drawer/1` and `sheet/1`: a dialog over a backdrop, drawn hidden and opened
  by `Phoenix.LiveView.JS`. The drawer comes from the right side from 640px and is a bottom sheet
  below; the sheet is a bottom sheet at every width. A `confirm_close` question stands on the close
  button and the backdrop, and Escape closes only a panel without one.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.UIAdapters.Tailwind
  alias Phoenix.LiveView.JS

  defp render(fun, assigns) do
    assigns =
      Map.merge(
        %{__changed__: nil, id: "edit", inner_block: body(), title: "Edit product"},
        assigns
      )

    Tailwind
    |> apply(fun, [assigns])
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp body do
    assigns = %{}

    inner_block = fn _changed, _arg ->
      ~H"""
      <p id="body">Body</p>
      """
    end

    [%{__slot__: :inner_block, inner_block: inner_block}]
  end

  defp one(doc, selector), do: LazyHTML.query(doc, selector)
  defp attr(doc, selector, name), do: doc |> one(selector) |> LazyHTML.attribute(name)

  for fun <- [:drawer, :sheet] do
    describe "#{fun}" do
      test "is a labelled dialog over a backdrop, drawn hidden, holding its body" do
        doc = render(unquote(fun), %{})

        assert attr(doc, "#edit", "class") |> hd() =~ "hidden"
        assert attr(doc, "#edit-panel", "role") == ["dialog"]
        assert attr(doc, "#edit-panel", "aria-modal") == ["true"]
        assert attr(doc, "#edit-panel", "aria-labelledby") == ["edit-title"]
        assert one(doc, "#edit-title") |> LazyHTML.text() =~ "Edit product"
        assert one(doc, "#edit-panel #body") |> Enum.count() == 1
        assert one(doc, "#edit-backdrop[aria-hidden]") |> Enum.count() == 1
      end

      test "opens as it is drawn with show, and not without" do
        assert attr(render(unquote(fun), %{show: true}), "#edit", "phx-mounted") |> hd() =~
                 "edit-panel"

        assert attr(render(unquote(fun), %{}), "#edit", "phx-mounted") == []
      end

      test "closes from its button, its backdrop and Escape, running on_close" do
        doc = render(unquote(fun), %{on_close: JS.push("close_drawer")})

        for selector <- [~s|[data-role="gervaz-panel-close"]|, "#edit-backdrop"] do
          [click] = attr(doc, selector, "phx-click")
          assert click =~ "close_drawer"
          assert click =~ "edit-panel"
        end

        assert attr(doc, "#edit-panel", "phx-window-keydown") |> hd() =~ "close_drawer"
        assert attr(doc, "#edit-panel", "phx-key") == ["escape"]
      end

      test "asks its confirm_close first, and then Escape does not close it" do
        doc = render(unquote(fun), %{confirm_close: "Discard your changes?"})

        assert attr(doc, ~s|[data-role="gervaz-panel-close"]|, "data-confirm") == [
                 "Discard your changes?"
               ]

        assert attr(doc, "#edit-backdrop", "data-confirm") == ["Discard your changes?"]
        assert attr(doc, "#edit-panel", "phx-window-keydown") == []
      end
    end
  end

  defp actions_slot do
    assigns = %{}

    inner_block = fn _changed, _arg ->
      ~H"""
      <button id="archive">Archive</button>
      """
    end

    [%{__slot__: :actions, inner_block: inner_block}]
  end

  defp head(doc), do: one(doc, ~s|[data-role="gervaz-panel-head"]|)

  for fun <- [:drawer, :sheet] do
    describe "#{fun} head" do
      test "draws the icon tile in its tone, the sub line and the chips under the title" do
        doc =
          render(unquote(fun), %{
            icon: "hero-receipt-percent",
            tone: :warn,
            sub: "MS-1042 · Jane Doe",
            chips: [{:ok, "Paid"}, "Card"]
          })

        [tile] = attr(doc, ~s|[data-role="gervaz-panel-tile"]|, "data-tone")
        assert tile == "warn"

        assert one(doc, ~s|[data-role="gervaz-panel-tile"] .hero-receipt-percent|) |> Enum.count() ==
                 1

        assert one(doc, "#edit-sub") |> LazyHTML.text() =~ "MS-1042 · Jane Doe"
        assert attr(doc, "#edit-panel", "aria-describedby") == ["edit-sub"]

        chips = one(doc, ~s|[data-role="gervaz-panel-chip"]|)
        assert Enum.map(chips, &LazyHTML.text/1) |> Enum.map(&String.trim/1) == ["Paid", "Card"]
        assert LazyHTML.attribute(chips, "data-tone") == ["ok", "mute"]
      end

      test "draws no tile, sub line or chips when none is given" do
        doc = render(unquote(fun), %{})

        assert one(doc, ~s|[data-role="gervaz-panel-tile"]|) |> Enum.count() == 0
        assert one(doc, "#edit-sub") |> Enum.count() == 0
        assert one(doc, ~s|[data-role="gervaz-panel-chip"]|) |> Enum.count() == 0
      end

      test "puts its actions in the foot, or in the head beside the close button" do
        foot = render(unquote(fun), %{actions: actions_slot()})

        assert one(foot, ~s|[data-role="gervaz-panel-footer"] #archive|) |> Enum.count() == 1
        assert foot |> head() |> LazyHTML.query("#archive") |> Enum.count() == 0

        top = render(unquote(fun), %{actions: actions_slot(), actions_at: :head})

        assert top
               |> head()
               |> LazyHTML.query(~s|[data-role="gervaz-panel-actions"] #archive|)
               |> Enum.count() == 1

        assert one(top, ~s|[data-role="gervaz-panel-footer"]|) |> Enum.count() == 0
      end
    end
  end

  test "the drawer comes from the end side from 640px and rises from the bottom below" do
    [class] = attr(render(:drawer, %{}), "#edit-panel", "class")

    assert class =~ "inset-x-0 bottom-0"
    assert class =~ "sm:inset-y-0 sm:start-auto sm:end-0"
    assert attr(render(:drawer, %{}), "#edit", "data-role") == ["gervaz-drawer"]
  end

  test "the sheet rises from the bottom at every width" do
    doc = render(:sheet, %{})
    [class] = attr(doc, "#edit-panel", "class")

    assert class =~ "inset-x-0 bottom-0"
    refute class =~ "sm:end-0"
    assert attr(doc, "#edit", "data-role") == ["gervaz-sheet"]
  end

  test "show_drawer/2 and hide_drawer/2 move the panel in and out by JS" do
    assert %JS{ops: [_ | _]} = Tailwind.show_drawer("edit")
    assert %JS{ops: [_ | _]} = Tailwind.hide_sheet(JS.push("closed"), "edit")
  end
end

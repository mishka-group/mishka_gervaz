defmodule MishkaGervaz.UIAdapters.TailwindDrawerTest do
  @moduledoc """
  The default adapter's `drawer/1`, `sheet/1` and `window/1`: a dialog over a backdrop, drawn hidden
  and opened by `Phoenix.LiveView.JS`, its focus kept inside it. The drawer comes from the right side
  from 640px and is a bottom sheet below; the sheet is a bottom sheet at every width; the window is
  in the middle of the screen from 640px and a bottom sheet below. A `confirm_close` question stands
  on the close button and the backdrop, Escape closes only a panel without one, and a
  `request_close` runs in place of the close.
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

  for fun <- [:drawer, :sheet, :window] do
    describe "#{fun}" do
      test "is a labelled dialog over a backdrop, drawn hidden, holding its body" do
        doc = render(unquote(fun), %{})

        assert attr(doc, "#edit", "class") |> hd() =~ "hidden"
        assert attr(doc, "#edit-panel", "role") == ["dialog"]
        assert attr(doc, "#edit-panel", "aria-modal") == ["true"]
        assert attr(doc, "#edit-panel", "aria-labelledby") == ["edit-title"]
        assert one(doc, "#edit-title") |> LazyHTML.text() =~ "Edit product"
        assert one(doc, "#edit-panel #edit-body #body") |> Enum.count() == 1
        assert one(doc, "#edit-backdrop[aria-hidden]") |> Enum.count() == 1
      end

      test "keeps the focus inside its panel" do
        doc = render(unquote(fun), %{})

        assert attr(doc, "#edit-panel", "phx-hook") == ["Phoenix.FocusWrap"]
        assert one(doc, "#edit-panel > #edit-panel-start[tabindex]") |> Enum.count() == 1
        assert one(doc, "#edit-panel > #edit-panel-end[tabindex]") |> Enum.count() == 1
      end

      test "runs its request_close in place of the close, from its button, its backdrop and Escape" do
        doc =
          render(unquote(fun), %{
            request_close: JS.push("ask_close"),
            on_close: JS.push("close_drawer")
          })

        for selector <- ["#edit-close", "#edit-backdrop"] do
          [click] = attr(doc, selector, "phx-click")
          assert click =~ "ask_close"
          refute click =~ "close_drawer"
          refute click =~ "edit-panel"
        end

        assert attr(doc, "#edit-panel", "phx-window-keydown") |> hd() =~ "ask_close"
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

  for fun <- [:drawer, :sheet, :window] do
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

  test "the window stands in the middle of the screen from 640px and rises from the bottom below" do
    doc = render(:window, %{})
    [class] = attr(doc, "#edit-panel", "class")

    assert class =~ "inset-x-0 bottom-0"
    assert class =~ "sm:inset-0 sm:m-auto sm:h-fit"
    assert class =~ "sm:w-[min(560px,calc(100vw-48px))]"
    refute class =~ "sm:end-0"
    assert attr(doc, "#edit", "data-role") == ["gervaz-window"]
  end

  test "a window's class replaces its width" do
    [class] = attr(render(:window, %{class: "sm:w-[720px]"}), "#edit-panel", "class")

    assert class =~ "sm:w-[720px]"
    refute class =~ "560px"
  end

  test "a window without a title draws no head and puts its close button in the corner" do
    doc = render(:window, %{title: nil, on_close: JS.push("close_window")})

    assert head(doc) |> Enum.count() == 0
    assert attr(doc, "#edit-panel", "aria-labelledby") == []
    assert attr(doc, "#edit-close", "phx-click") |> hd() =~ "close_window"
    assert attr(doc, "#edit-close", "aria-label") == ["Close"]
  end

  test "a drawer without a title keeps its head with the close button" do
    doc = render(:drawer, %{title: nil})

    assert head(doc) |> LazyHTML.query("#edit-close") |> Enum.count() == 1
  end

  test "show_drawer/2 and hide_drawer/2 move the panel in and out by JS" do
    assert %JS{ops: [_ | _]} = Tailwind.show_drawer("edit")
    assert %JS{ops: [_ | _]} = Tailwind.hide_sheet(JS.push("closed"), "edit")
  end

  test "show_window/2 opens the window's panel and focuses in it, hide_window/2 hands the focus back" do
    shown = Jason.encode!(Tailwind.show_window("edit").ops)
    hidden = Jason.encode!(Tailwind.hide_window(JS.push("closed"), "edit").ops)

    assert shown =~ "#edit-panel"
    assert shown =~ "focus_first"
    assert shown =~ "sm:scale-95"
    assert hidden =~ "closed"
    assert hidden =~ "pop_focus"
  end
end

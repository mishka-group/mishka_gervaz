defmodule MishkaGervaz.Types.Column.TagsTest do
  @moduledoc """
  Tests for the Tags column type: it renders a list as individual chips, reading the raw list from
  the record (NOT the space-joined display string the table hands type modules for array values).
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.Table.Types.Column.Tags

  @ui MishkaGervaz.UIAdapters.Tailwind

  defp column(extra \\ %{}, source \\ :dependencies) do
    %{name: source, source: source, ui: %{type: :tags, extra: extra}}
  end

  defp render(record, column \\ column()) do
    # The first arg is the table's joined display string; Tags must ignore it and read the record.
    joined =
      MishkaGervaz.Table.Behaviours.Template.get_cell_value(record, %{
        source: column.source,
        default: nil,
        separator: nil
      })

    rendered_to_string(Tags.render(joined, column, record, @ui))
  end

  describe "behaviour implementation" do
    test "implements ColumnType and defines render/4" do
      behaviours = Tags.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ColumnType in behaviours
      assert function_exported?(Tags, :render, 4)
    end
  end

  describe "a chip given as a map" do
    test "wears its own class and tooltip, and its label as the text" do
      html =
        render(%{
          dependencies: [%{label: "FA", class: "chip-fa", title: "FA — missing"}, "plain"]
        })

      assert html =~ ~s(class="chip-fa")
      assert html =~ ~s(title="FA — missing")
      assert html =~ ">FA<"
      refute html =~ "%{"
    end

    test "falls back to the column's chip class when it names none" do
      html = render(%{dependencies: [%{label: "EN"}]}, column(%{badge_class: "chip-default"}))

      assert html =~ ~s(class="chip-default")
      refute html =~ "title="
    end

    test "counts toward +N like any other chip" do
      chips = for code <- ~w(en fa fr de), do: %{label: String.upcase(code)}

      html = render(%{dependencies: chips}, column(%{max_items: 3}))

      assert html =~ "+1"
      assert html =~ "DE"
    end
  end

  describe "render/4" do
    test "reads the raw list from the record, not the joined display string" do
      html = render(%{dependencies: ["chelekom-image", "chelekom-icon"]})

      # each dependency is its OWN chip — never one chip holding the joined string
      assert html =~ "chelekom-image"
      assert html =~ "chelekom-icon"
      refute html =~ "chelekom-image chelekom-icon"
    end

    test "shows the first 2 inline and collapses the rest behind +N" do
      html = render(%{dependencies: ["a", "b", "c", "d"]})

      assert html =~ ">a<"
      assert html =~ ">b<"
      assert html =~ "+2"
      # the rest are rendered inline but hidden, revealed on click via a JS class swap (no :focus)
      assert html =~ "hidden"
      assert html =~ "phx-click"
      assert html =~ "phx-click-away"
      assert html =~ ">c<"
      assert html =~ ">d<"
    end

    test "+N is a toggle: it carries a collapse handle and toggle_class JS, not a one-way reveal" do
      html = render(%{dependencies: ["a", "b", "c", "d"]})

      # the chip swaps +N ⇄ "- less" (the collapse handle is rendered, hidden until expanded)
      assert html =~ "- less"
      assert html =~ ~s(id="gz-tags-dependencies-77541892-less")
      # the click toggles classes (so a second click collapses), not a one-way add/remove
      assert html =~ "toggle_class"
    end

    test "namespaces every id by the column source so multiple :tags columns stay independent" do
      record = %{id: "rec-1", dependencies: ["a", "b", "c"], categories: ["x", "y", "z"]}

      deps_html = render(record, column())
      cats_html = render(record, column(%{}, :categories))

      assert deps_html =~ "gz-tags-dependencies-rec-1-rest"
      assert cats_html =~ "gz-tags-categories-rec-1-rest"
      # the two columns never share an element id
      refute deps_html =~ "gz-tags-categories"
      refute cats_html =~ "gz-tags-dependencies"
    end

    test "no +N when the list fits within max_items" do
      html = render(%{dependencies: ["only-one"]})

      assert html =~ "only-one"
      refute html =~ "phx-click"
      refute html =~ "+1"
    end

    test "respects a custom :max_items from ui.extra" do
      html = render(%{dependencies: ["a", "b", "c", "d"]}, column(%{max_items: 3}))

      assert html =~ "+1"
    end

    test "renders an empty marker for an empty or nil list" do
      assert render(%{dependencies: []}) =~ "—"
      assert render(%{dependencies: nil}) =~ "—"
    end

    test "drops nil/blank entries" do
      html = render(%{dependencies: ["real", nil, ""]})

      assert html =~ "real"
      refute html =~ "+1"
      refute html =~ "+2"
    end
  end
end

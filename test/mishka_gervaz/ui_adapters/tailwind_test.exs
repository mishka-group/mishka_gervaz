defmodule MishkaGervaz.UIAdapters.TailwindTest do
  @moduledoc """
  Tests for `MishkaGervaz.UIAdapters.Tailwind.select/1` — flat options stay flat
  `<option>`s; a `{group_label, [opts]}` entry becomes an `<optgroup>` — and for the row action
  buttons, which dim while their click is pending, for the copy button, which shows the copied
  state from the `data-copied` attribute the host's hook sets, and for the tab strip of a `:tabs`
  form, which scrolls the shown tab into view.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.UIAdapters.Tailwind

  defp select(assigns) do
    base = %{name: :resource, value: nil, prompt: "All"}
    render_component(&Tailwind.select/1, Map.merge(base, assigns))
  end

  describe "select/1 empty choice" do
    defp bare_select(assigns) do
      render_component(
        &Tailwind.select/1,
        Map.merge(%{name: :status, value: nil, options: [{"Draft", "draft"}]}, assigns)
      )
    end

    test "a select given no prompt draws no empty choice" do
      html = bare_select(%{})

      refute html =~ ~s(<option value="">)
      refute html =~ ">All<"
    end

    test "a filter select given no prompt is All" do
      html = bare_select(%{variant: :filter})

      assert html =~ ~r/<option value="">\s*All\s*<\/option>/
    end

    test "an explicit prompt is honoured, filter or not" do
      assert bare_select(%{prompt: "Pick one"}) =~ ~r/<option value="">\s*Pick one\s*<\/option>/

      assert bare_select(%{prompt: "Pick one", variant: :filter}) =~
               ~r/<option value="">\s*Pick one\s*<\/option>/
    end

    test "a nil prompt draws no empty choice, filter or not" do
      refute bare_select(%{prompt: nil, variant: :filter}) =~ ~s(<option value="">)
    end
  end

  describe "select/1 grouped options" do
    test "flat options render plain <option> and no <optgroup>" do
      html = select(%{options: [{"Active", "active"}, {"Archived", "archived"}]})

      assert html =~ ~s(<option value="active")
      assert html =~ "Active"
      assert html =~ ~s(<option value="archived")
      refute html =~ "<optgroup"
    end

    test "grouped options render an <optgroup> per group with nested <option>" do
      html =
        select(%{
          options: [
            {"Mishka Blog", [{"Tag", "Elixir.MishkaBlog.Tag"}]},
            {"Mishka Document", [{"Tag", "Elixir.MishkaDocument.Tag"}]}
          ]
        })

      assert html =~ ~s(<optgroup label="Mishka Blog">)
      assert html =~ ~s(<optgroup label="Mishka Document">)
      # same display label, but distinct values under their own groups
      assert html =~ ~s(<option value="Elixir.MishkaBlog.Tag")
      assert html =~ ~s(<option value="Elixir.MishkaDocument.Tag")
    end

    test "flat and grouped entries can be mixed" do
      html =
        select(%{
          options: [
            {"All jobs", "__job__"},
            {"Mishka Blog", [{"Blog Post", "Elixir.MishkaBlog.BlogPost"}]}
          ]
        })

      assert html =~ ~s(<option value="__job__")
      assert html =~ ~s(<optgroup label="Mishka Blog">)
      assert html =~ ~s(<option value="Elixir.MishkaBlog.BlogPost")
    end

    test "the matching value is marked selected, flat or inside a group" do
      flat = select(%{value: "active", options: [{"Active", "active"}, {"Archived", "archived"}]})
      assert flat =~ ~r/value="active"[^>]*selected/

      grouped =
        select(%{
          value: "Elixir.MishkaBlog.BlogPost",
          options: [{"Mishka Blog", [{"Blog Post", "Elixir.MishkaBlog.BlogPost"}]}]
        })

      assert grouped =~ ~r/value="Elixir.MishkaBlog.BlogPost"[^>]*selected/
    end
  end

  describe "a row action" do
    test "dims and stops taking clicks while its click is pending, in every variant" do
      for variant <- [:default, :danger, :destroy, :permanent_destroy, :unarchive] do
        html =
          render_component(&Tailwind.button/1, %{
            label: "Edit",
            icon: "hero-pencil",
            variant: variant
          })

        assert html =~ "phx-click-loading:opacity-70", inspect(variant)
        assert html =~ "phx-click-loading:pointer-events-none", inspect(variant)
      end
    end

    test "dims as a link too" do
      for variant <- [:edit, :show, :external] do
        html =
          render_component(&Tailwind.nav_link/1, %{
            label: "View",
            navigate: "/x",
            variant: variant
          })

        assert html =~ "phx-click-loading:opacity-70", inspect(variant)
      end
    end
  end

  describe "step_indicator/1 as tabs" do
    test "the tab strip carries the hook that scrolls the shown tab into view" do
      html =
        render_component(&Tailwind.step_indicator/1, %{
          tabs: true,
          id: "plan",
          steps: [%{name: :basics, label: "Basics", status: :active}],
          current_step: :basics,
          navigable: [:basics]
        })

      [strip] =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(~s|[role="tablist"]|)
        |> Enum.to_list()

      assert LazyHTML.attribute(strip, "id") == ["plan-tabs"]
      assert [hook] = LazyHTML.attribute(strip, "phx-hook")
      assert String.ends_with?(hook, ".ShownTab")
    end
  end

  describe "copy_button/1" do
    defp copy_button(assigns \\ %{}) do
      html =
        render_component(
          &Tailwind.copy_button/1,
          Map.merge(%{id: "copy-id-1", value: "0b9f-41c2"}, assigns)
        )

      LazyHTML.from_fragment(html)
    end

    defp classes(node), do: node |> LazyHTML.attribute("class") |> hd() |> String.split()

    test "copies its value through the host hook and lets LiveView keep the value current" do
      button = LazyHTML.query(copy_button(), "button#copy-id-1")

      assert LazyHTML.attribute(button, "phx-hook") == ["CopyToClipboard"]
      assert LazyHTML.attribute(button, "data-copy") == ["0b9f-41c2"]
      assert LazyHTML.attribute(button, "phx-update") == []
    end

    test "swaps the copy icon for a check icon while data-copied is set, at one fixed size" do
      html = copy_button()
      button = LazyHTML.query(html, "button")
      copy_icon = LazyHTML.query(html, ~s([data-role="gervaz-copy-icon"]))
      copied_icon = LazyHTML.query(html, ~s([data-role="gervaz-copied-icon"]))

      assert "group" in classes(button)
      assert "size-3" in classes(button)

      refute "hidden" in classes(copy_icon)
      assert "group-data-[copied]:hidden" in classes(copy_icon)

      assert "hidden" in classes(copied_icon)
      assert "group-data-[copied]:block" in classes(copied_icon)

      assert "size-3" in classes(copy_icon)
      assert "size-3" in classes(copied_icon)
    end

    test "is named by its label and tells screen readers when it copied" do
      html = copy_button(%{label: "Copy the id"})
      button = LazyHTML.query(html, "button")
      region = LazyHTML.query(html, ~s([aria-live="polite"]))
      announcement = LazyHTML.query(html, ~s([aria-live="polite"] > span))

      assert LazyHTML.attribute(button, "aria-label") == ["Copy the id"]
      assert "sr-only" in classes(region)
      assert LazyHTML.text(announcement) == "Copied"
      assert "hidden" in classes(announcement)
      assert "group-data-[copied]:inline" in classes(announcement)
    end
  end
end

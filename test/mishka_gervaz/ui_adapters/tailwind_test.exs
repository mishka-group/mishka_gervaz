defmodule MishkaGervaz.UIAdapters.TailwindTest do
  @moduledoc """
  Tests for `MishkaGervaz.UIAdapters.Tailwind.select/1` — flat options stay flat
  `<option>`s; a `{group_label, [opts]}` entry becomes an `<optgroup>`.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.UIAdapters.Tailwind

  defp select(assigns) do
    base = %{name: :resource, value: nil, prompt: "All"}
    render_component(&Tailwind.select/1, Map.merge(base, assigns))
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
end

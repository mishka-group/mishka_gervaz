defmodule MishkaGervaz.Table.Templates.DateRangeFilterTest do
  @moduledoc """
  A `:date_range` filter is one filter in the filter row, shaped like the ones beside it: its own
  label over the two date inputs, which sit side by side with an arrow between them and keep the
  `<name>_from` / `<name>_to` names the filter event and the URL read.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  @backend MishkaGervaz.Test.Gettext
  @fa "[fa:mishka_gervaz] "

  defp render_filters(filter_values) do
    state =
      "date-range"
      |> State.init(ComplexTestResource, %{id: "user-1", role: :admin})
      |> State.update(loading: :loaded, has_initial_data?: true)

    state = %{
      state
      | static: %{state.static | filter_groups: []},
        filter_values: Map.merge(state.filter_values, filter_values)
    }

    render_component(&Shared.render_filters/1, %{
      static: state.static,
      state: state,
      myself: nil,
      __changed__: %{}
    })
  end

  defp date_range_group(html) do
    [_, group] =
      Regex.run(
        ~r/(<div role="group"[^>]*data-role="gervaz-date-range-filter".*?<\/div>\s*<\/div>\s*<\/div>)/s,
        html
      )

    group
  end

  test "is one group with one label, the filter's own" do
    html = render_filters(%{})

    assert length(Regex.scan(~r/data-role="gervaz-date-range-filter"/, html)) == 1

    group = date_range_group(html)

    assert group =~ ~s(aria-label="Created Between")
    assert length(Regex.scan(~r/<label/, group)) == 1
    assert group =~ ~r/<label[^>]*>\s*Created Between\s*<\/label>/
    refute html =~ ~r/<label[^>]*>\s*From\s*<\/label>/
    refute html =~ ~r/<label[^>]*>\s*To\s*<\/label>/
  end

  test "keeps a whole date in view and wraps as one unit" do
    group = render_filters(%{}) |> date_range_group()

    assert group =~ ~s|class="min-w-[min(100%,310px)] flex-[1.6]"|
    assert length(Regex.scan(~r/min-w-\[140px\]/, group)) == 2
    refute group =~ "min-w-0 flex-1"
  end

  test "sits in the same row as the other filters, labelled the way they are" do
    html = render_filters(%{})

    [_, row] = Regex.run(~r/<div class="flex flex-wrap items-end gap-\[14px\]">(.*)/s, html)

    assert row =~ "gervaz-date-range-filter"
    assert row =~ ~s(<label class="mb-1.5 block text-[10.5px] font-bold text-[#8a877f]">)
  end

  test "draws the range it holds, from before to, under the names the URL reads" do
    group =
      render_filters(%{date_range: %{from: "2026-09-24", to: "2026-09-26"}})
      |> date_range_group()

    assert group =~
             ~r/name="date_range_from" value="2026-09-24".*&rarr;.*name="date_range_to" value="2026-09-26"/s
  end

  test "names its inputs in the caller's locale" do
    Gettext.put_locale(@backend, "fa")
    group = render_filters(%{}) |> date_range_group()

    assert group =~ ~s(aria-label="#{@fa}From")
    assert group =~ ~s(aria-label="#{@fa}To")
  after
    Gettext.put_locale(@backend, "en")
  end
end

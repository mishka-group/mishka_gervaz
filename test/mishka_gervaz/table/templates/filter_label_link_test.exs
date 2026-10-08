defmodule MishkaGervaz.Table.Templates.FilterLabelLinkTest do
  @moduledoc """
  A filter's label names its control, a filter with no label of its own names itself, and the ids
  are the table's own, so two tables on one page never share one.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.ComplexTestResource

  defp render_filters(table_id) do
    state =
      table_id
      |> State.init(ComplexTestResource, %{id: "user-1", role: :admin})
      |> State.update(loading: :loaded, has_initial_data?: true)

    state = %{state | static: %{state.static | filter_groups: []}}

    render_component(&Shared.render_filters/1, %{
      static: state.static,
      state: state,
      myself: nil,
      __changed__: %{}
    })
  end

  defp ids(html), do: values(html, ~r/\sid="([^"]+)"/)
  defp label_fors(html), do: values(html, ~r/<label\b[^>]*?\sfor="([^"]+)"/s)

  defp values(html, regex),
    do: regex |> Regex.scan(html, capture: :all_but_first) |> List.flatten()

  defp control_with_id?(html, id),
    do: html =~ ~r/<(input|select|textarea|button)\b[^>]*\sid="#{Regex.escape(id)}"/s

  for {name, kind} <- [search: "text", status: "select", author_id: "relation"] do
    test "a #{kind} filter's label names its control" do
      html = render_filters("posts")
      id = "posts-filter-#{unquote(name)}"

      assert id in label_fors(html)
      assert control_with_id?(html, id)
    end
  end

  test "a filter drawn without a label names itself" do
    html = render_filters("posts")

    assert html =~ ~r/<input\b[^>]*\sid="posts-filter-view_count"[^>]*\saria-label="Min Views"/s
  end

  test "every label names an element on the page" do
    html = render_filters("posts")
    on_page = MapSet.new(ids(html))

    assert label_fors(html) != []
    for id <- label_fors(html), do: assert(id in on_page, "no element has the id #{id}")
  end

  test "the page size select is named by the words beside it" do
    state =
      "posts"
      |> State.init(ComplexTestResource, %{id: "user-1", role: :admin})
      |> State.update(loading: :loaded, has_initial_data?: true)

    state = %{state | total_pages: 3, total_count: 50}

    html =
      render_component(&Shared.render_pagination/1, %{
        static: state.static,
        state: state,
        myself: nil,
        __changed__: %{}
      })

    assert html =~
             ~r/<select[^>]*name="size"[^>]*aria-labelledby="posts-page-size-show posts-page-size-unit"/s

    assert html =~ ~r/<span id="posts-page-size-show"[^>]*>\s*Show\s*<\/span>/s
    assert html =~ ~r/<span id="posts-page-size-unit"[^>]*>\s*per page\s*<\/span>/s
  end

  test "two tables on one page share no id" do
    a = render_filters("posts")
    b = render_filters("drafts")

    assert MapSet.disjoint?(MapSet.new(ids(a)), MapSet.new(ids(b)))
  end
end

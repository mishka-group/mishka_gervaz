defmodule MishkaGervaz.Table.Templates.PageSizeSelectorTest do
  @moduledoc """
  `page_size_options` has no default: a table that sets none draws no page size selector, and one
  that sets a list draws a selector with exactly those sizes.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Entities.Pagination
  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.ComplexTestResource
  alias MishkaGervaz.Test.Resources.InfiniteScrollResource
  alias MishkaGervaz.Test.Resources.NumberedScrollResource

  defp render_pagination(resource, id) do
    state =
      id
      |> State.init(resource, %{id: "user-1", role: :admin})
      |> State.update(loading: :loaded, has_initial_data?: true, total_pages: 3, total_count: 50)

    render_component(&Shared.render_pagination/1, %{
      static: state.static,
      state: state,
      myself: nil,
      __changed__: %{}
    })
  end

  defp selector_form?(html, id), do: html =~ ~s(id="#{id}-page-size-selector-form")

  test "the option has no default" do
    assert Pagination.default(:page_size_options) == nil
    assert Pagination.defaults().page_size_options == nil
  end

  test "a table that sets no list keeps none" do
    assert State.init("posts", NumberedScrollResource, nil).static.page_size_options == nil
    assert State.init("posts", InfiniteScrollResource, nil).static.page_size_options == nil
  end

  test "a numbered table with no list draws no page size selector" do
    html = render_pagination(NumberedScrollResource, "numbered")

    refute selector_form?(html, "numbered")
    refute html =~ ~s(name="size")
  end

  test "an infinite table with no list draws no page size selector" do
    html = render_pagination(InfiniteScrollResource, "infinite")

    refute selector_form?(html, "infinite")
    refute html =~ ~s(name="size")
  end

  test "a table with a list draws a selector with exactly those sizes, the current one chosen" do
    html = render_pagination(ComplexTestResource, "posts")

    assert selector_form?(html, "posts")

    sizes =
      ~r/<option[^>]*value="(\d+)"/
      |> Regex.scan(html, capture: :all_but_first)
      |> List.flatten()

    assert sizes == ["10", "20", "50", "100"]
    assert html =~ ~r/<option[^>]*value="20"[^>]*selected/
  end

  test "a table with an empty list draws no page size selector" do
    state = State.init("posts", ComplexTestResource, %{id: "user-1", role: :admin})

    state =
      state
      |> State.update(loading: :loaded, has_initial_data?: true, total_pages: 3, total_count: 50)
      |> then(&%{&1 | static: %{&1.static | page_size_options: []}})

    html =
      render_component(&Shared.render_pagination/1, %{
        static: state.static,
        state: state,
        myself: nil,
        __changed__: %{}
      })

    refute selector_form?(html, "posts")
  end
end

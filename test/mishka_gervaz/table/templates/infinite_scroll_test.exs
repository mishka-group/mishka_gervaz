defmodule MishkaGervaz.Table.Templates.InfiniteScrollTest do
  @moduledoc """
  Tests that the `:infinite` pagination type wires `phx-viewport-bottom` so that scrolling triggers
  `load_more`, per the Phoenix.LiveView bindings docs.

  Reference:
  https://hexdocs.pm/phoenix_live_view/bindings.html#scroll-events-and-infinite-pagination

  The binding sits on a sentinel element below the records rather than on the `phx-update="stream"`
  parent itself: the card-grid redesign made the table's scroller conditional on there being records,
  and a sentinel still fires when the list is short enough that the stream parent never leaves the
  viewport.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.InfiniteScrollResource
  alias MishkaGervaz.Test.Resources.NumberedScrollResource

  import Phoenix.LiveViewTest

  defp render_table(resource, state_opts) do
    state = State.init("test-id", resource, nil)

    state =
      State.update(state, Keyword.merge([loading: :loaded, has_initial_data?: true], state_opts))

    stream_name = state.static.stream_name

    assigns = %{
      static: state.static,
      state: state,
      stream: [],
      streams: %{stream_name => []},
      empty?: false,
      failed?: false,
      myself: nil,
      __changed__: %{}
    }

    render_component(&TableTemplate.render/1, assigns)
  end

  describe "pagination_type/1 helper" do
    test "returns :numbered when DSL config has type :numbered" do
      state = State.init("t", NumberedScrollResource, nil)
      assert TableTemplate.pagination_type(state.static) == :numbered
    end

    test "returns :infinite when DSL config has type :infinite" do
      state = State.init("t", InfiniteScrollResource, nil)
      assert TableTemplate.pagination_type(state.static) == :infinite
    end
  end

  describe "render/1 — :infinite pagination with has_more?" do
    test "tbody has phx-update='stream' and phx-viewport-bottom='load_more'" do
      html = render_table(InfiniteScrollResource, has_more?: true, page: 1)

      assert html =~ ~s(phx-update="stream")
      assert html =~ ~s(phx-viewport-bottom="load_more")
    end

    test "binding stays set even during a load (page_loading flag handles re-entry)" do
      html = render_table(InfiniteScrollResource, has_more?: true, loading: :loading)

      assert html =~ "phx-viewport-bottom"
    end
  end

  describe "render/1 — gating off the binding" do
    test "no phx-viewport-bottom when has_more? is false (end of stream)" do
      html = render_table(InfiniteScrollResource, has_more?: false)

      refute html =~ "phx-viewport-bottom"
    end

    test "no phx-viewport-bottom for :numbered pagination" do
      html = render_table(NumberedScrollResource, has_more?: true)

      refute html =~ "phx-viewport-bottom"
    end
  end
end

defmodule MishkaGervaz.Table.Web.RendererTest do
  @moduledoc """
  Tests for the Renderer module.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.Renderer
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.User

  import Phoenix.LiveViewTest

  # Mock template module for testing
  defmodule MockTemplate do
    use Phoenix.Component

    def render(assigns) do
      # Handle stream which can be list or tuple
      stream_count = stream_length(assigns.stream)
      assigns = assign(assigns, :stream_count, stream_count)

      ~H"""
      <div data-testid="mock-template">
        <span data-static-id={@static.id}></span>
        <span data-state-page={@state.page}></span>
        <span data-stream-count={@stream_count}></span>
        <span data-empty={to_string(@empty?)}></span>
      </div>
      """
    end

    def render_loading(assigns) do
      ~H"""
      <div data-testid="mock-loading" data-loading-static={@static && @static.id}>Loading...</div>
      """
    end

    defp stream_length(stream) when is_list(stream), do: length(stream)
    defp stream_length({_, _, items}) when is_list(items), do: length(items)
    defp stream_length(_), do: 0
  end

  # What a skeleton is allowed to look like: several in this codebase are one component call and
  # nothing else, which is not the single static tag a stateful component may have at its root.
  defmodule RootlessTemplate do
    use Phoenix.Component

    def render(assigns), do: ~H'<div data-testid="rootless-template"></div>'

    def render_loading(assigns) do
      assigns = assign_new(assigns, :rows, fn -> 2 end)

      ~H"""
      <.rows count={@rows} />
      """
    end

    defp rows(assigns) do
      ~H"""
      <div :for={_row <- 1..@count//1} data-testid="rootless-row"></div>
      """
    end
  end

  # Loaded unless a test says otherwise: `render/1` draws the template's loading state until the
  # first read returns, so a state fresh from `State.init/3` would answer every question about
  # assigns, streams and template choice with the skeleton.
  defp create_state(opts \\ []) do
    state = State.init("test-id", User, nil)
    defaults = [template: MockTemplate, has_initial_data?: true, loading: :loaded]

    State.update(state, Keyword.merge(defaults, opts))
  end

  defp create_assigns(state, opts \\ []) do
    stream_name = state.static.stream_name
    streams = Keyword.get(opts, :streams, %{stream_name => []})

    %{
      table_state: state,
      streams: streams,
      __changed__: %{}
    }
  end

  describe "render/1" do
    test "dispatches to render_with_state when table_state is present" do
      state = create_state()
      assigns = create_assigns(state)

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-testid="mock-template")
      assert result =~ ~s(data-static-id="test-id")
    end

    test "dispatches to render_loading when table_state is nil" do
      assigns = %{table_state: nil, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)

      # Uses default Table template's render_loading which shows spinner
      assert result =~ "Loading"
    end

    test "uses default Table template when template is nil" do
      state = create_state(template: nil)
      assigns = create_assigns(state)

      # Should not raise - uses default template
      result = render_component(&Renderer.render/1, assigns)
      # Default template renders table structure
      assert result =~ "table" or result =~ "gervaz"
    end
  end

  describe "assigns preparation" do
    test "passes static from state.static" do
      state = create_state()
      assigns = create_assigns(state)

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-static-id="test-id")
    end

    test "passes state for dynamic fields" do
      state = create_state() |> State.update(page: 5)
      assigns = create_assigns(state)

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-state-page="5")
    end

    test "extracts stream by stream_name" do
      state = create_state()
      stream_name = state.static.stream_name

      mock_stream = [{"id-1", %{id: "1"}}, {"id-2", %{id: "2"}}]
      assigns = create_assigns(state, streams: %{stream_name => mock_stream})

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-stream-count="2")
    end

    test "returns empty list when stream not found" do
      state = create_state()
      assigns = create_assigns(state, streams: %{other_stream: [{"id-1", %{}}]})

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-stream-count="0")
    end

    test "sets myself to nil by default" do
      state = create_state()
      assigns = create_assigns(state)

      # Should not raise when myself is not provided
      result = render_component(&Renderer.render/1, assigns)
      assert result =~ "mock-template"
    end
  end

  # `@empty?` is driven by `state.total_count` (the row count the data loader maintains for both
  # numbered and infinite pagination), not by stream introspection — a LiveView stream can't report
  # its own emptiness, and the old stream-based check both false-positived and false-negatived.
  describe "empty? detection (state.total_count)" do
    test "true once loaded with zero rows" do
      state = create_state(total_count: 0, has_initial_data?: true, loading: :loaded)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~ ~s(data-empty="true")
    end

    test "false when rows are present (e.g. after a load-more that added nothing)" do
      state = create_state(total_count: 23, has_initial_data?: true, loading: :loaded)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~ ~s(data-empty="false")
    end

    test "false during a reload" do
      state = create_state(total_count: 0, has_initial_data?: true, loading: :loading)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~ ~s(data-empty="false")
    end

    test "false after a FAILED load (stale count must not show empty)" do
      state = create_state(total_count: 0, loading: :error)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~ ~s(data-empty="false")
    end
  end

  describe "static/state separation" do
    test "static contains configuration fields" do
      state = create_state()

      assert state.static.id == "test-id"
      assert state.static.resource == User
      assert is_list(state.static.columns)
      assert is_list(state.static.filters)
      assert is_list(state.static.row_actions)
      assert is_list(state.static.bulk_actions)
    end

    test "state contains dynamic fields" do
      state = create_state() |> State.update(page: 3, loading: :loaded)

      assert state.page == 3
      assert state.loading == :loaded
      assert is_map(state.filter_values)
    end

    test "static reference remains same after state update" do
      state = create_state()
      original_static = state.static

      updated_state = State.update(state, page: 5, loading: :loading)

      # Same reference - enables O(1) comparison
      assert updated_state.static == original_static
    end
  end

  # The one question a template's loading state answers: is there anything to draw yet. A later page
  # or filter is not one of these — those keep the rows on screen and mark them stale.
  describe "the first read" do
    test "draws the template's loading state before it returns" do
      for loading <- [:initial, :loading] do
        state = create_state(has_initial_data?: false, loading: loading)

        assert render_component(&Renderer.render/1, create_assigns(state)) =~
                 ~s(data-testid="mock-loading")
      end
    end

    test "hands the loading state the static it is standing in for" do
      state = create_state(has_initial_data?: false, loading: :initial)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~
               ~s(data-loading-static="test-id")
    end

    test "draws the table again for a reload, which keeps its rows" do
      state = create_state(has_initial_data?: true, loading: :loading)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~
               ~s(data-testid="mock-template")
    end

    test "is over once a read has returned, however few rows it found" do
      state = create_state(has_initial_data?: true, loading: :loaded, total_count: 0)

      assert render_component(&Renderer.render/1, create_assigns(state)) =~
               ~s(data-testid="mock-template")
    end

    test "a loading state with no root tag of its own is still legal at a component root" do
      state =
        create_state(template: RootlessTemplate, has_initial_data?: false, loading: :initial)

      result = render_component(&Renderer.render/1, create_assigns(state)) |> String.trim()

      assert String.starts_with?(result, ~s(<div class="contents"))
      assert String.ends_with?(result, "</div>")
      assert result =~ ~s(data-testid="rootless-row")
    end

    test "first_read_out?/1 is the question itself" do
      assert Renderer.first_read_out?(create_state(has_initial_data?: false, loading: :initial))
      assert Renderer.first_read_out?(create_state(has_initial_data?: false, loading: :loading))
      refute Renderer.first_read_out?(create_state(has_initial_data?: true, loading: :loading))
      refute Renderer.first_read_out?(create_state(has_initial_data?: false, loading: :error))
    end
  end

  describe "template selection" do
    test "uses custom template when set in state" do
      state = create_state(template: MockTemplate)
      assigns = create_assigns(state)

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ "mock-template"
    end

    test "uses Grid template when configured" do
      state = create_state(template: MishkaGervaz.Table.Templates.Grid)

      # Verify template is set correctly in state
      assert state.template == MishkaGervaz.Table.Templates.Grid

      # Grid template would be used for actual rendering
      # (Full render test skipped due to complex template dependencies)
    end
  end
end

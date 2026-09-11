defmodule MishkaGervaz.Table.Web.Renderer do
  @moduledoc """
  Bridge between LiveComponent and Templates.

  This module is a thin orchestrator that:
  - Selects the appropriate template based on state
  - Prepares minimal assigns for the template
  - Delegates rendering to the template

  ## Architecture

      LiveComponent → Renderer (bridge) → Template → Shared (components)

  ## Performance Optimization

  Renderer passes two key assigns to templates:
  - `@static` - Same reference always, LiveView skips re-render (O(1) comparison)
  - `@state` - Changes trigger re-render only for parts using dynamic fields

  Templates should use:
  - `@static.*` for columns, filters, ui_adapter, etc. (no re-render on user interaction)
  - `@state.*` for page, filter_values, selected_ids, etc. (re-renders when changed)

  See `MishkaGervaz.Table.Web.Live`,
  `MishkaGervaz.Table.Web.State`,
  `MishkaGervaz.Table.Templates.Table`,
  `MishkaGervaz.Table.Behaviours.Template`.
  """

  use Phoenix.Component

  @doc """
  Renders the table through the template currently in effect.

  Until the first read returns, the template's `c:MishkaGervaz.Table.Behaviours.Template.render_loading/1`
  is drawn instead of its `render/1`. After that, `render/1` is passed `@static`, `@state`, the
  `@stream` for the resource's stream name and an `@empty?` flag.
  """
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    state = assigns[:table_state]

    if is_nil(state) or first_read_out?(state) do
      render_loading(assigns, state)
    else
      render_with_state(assigns, state)
    end
  end

  @doc """
  Whether the table has nothing to draw yet.

  True from the component's first render until the first read comes back, and never again — a later
  page, filter or sort keeps the rows on screen and marks them stale instead. A template's loading
  state answers this question and only this one.
  """
  @spec first_read_out?(MishkaGervaz.Table.Web.State.t()) :: boolean()
  def first_read_out?(state),
    do: not state.has_initial_data? and state.loading in [:initial, :loading]

  @spec render_with_state(map(), MishkaGervaz.Table.Web.State.t()) ::
          Phoenix.LiveView.Rendered.t()
  defp render_with_state(assigns, state) do
    template = state.template || MishkaGervaz.Table.Templates.Table

    assigns
    |> assign(:static, state.static)
    |> assign(:state, state)
    |> assign(:stream, get_stream(assigns, state.static.stream_name))
    |> assign(:empty?, table_empty?(state))
    |> assign_new(:myself, fn -> nil end)
    |> template.render()
  end

  # `@static` and `@state` are handed over when there are any, so a skeleton can be drawn to the
  # shape of the columns it is standing in for. Before the component has built its state there are
  # none, and both arrive as nil.
  #
  # The wrapper is what makes any loading state legal as the root of a stateful component, which is
  # a rule `render/1` meets by convention and a skeleton has no reason to know about: several are a
  # bare `<.loading />`, and a component call is not the single static tag LiveView demands. It is
  # `display: contents`, so the skeleton keeps whatever parent layout it was written for.
  @spec render_loading(map(), MishkaGervaz.Table.Web.State.t() | nil) ::
          Phoenix.LiveView.Rendered.t()
  defp render_loading(assigns, state) do
    template = (state && state.template) || MishkaGervaz.Table.Templates.Table

    inner =
      assigns
      |> assign(:static, state && state.static)
      |> assign(:state, state)
      |> assign_new(:myself, fn -> nil end)
      |> template.render_loading()

    assigns = assign(assigns, inner: inner, loading_id: state && state.static.id)

    ~H"""
    <div class="contents" data-gervaz-loading={@loading_id}>{@inner}</div>
    """
  end

  @spec get_stream(map(), atom()) :: list() | tuple()
  defp get_stream(assigns, stream_name) do
    case assigns[:streams] do
      %{^stream_name => stream} -> stream
      _ -> []
    end
  end

  @spec table_empty?(MishkaGervaz.Table.Web.State.t()) :: boolean()
  defp table_empty?(state) do
    state.loading == :loaded and state.total_count == 0
  end
end

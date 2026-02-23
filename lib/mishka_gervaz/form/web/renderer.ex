defmodule MishkaGervaz.Form.Web.Renderer do
  @moduledoc """
  Bridge between LiveComponent and Form Templates.

  This module is a thin orchestrator that:
  - Selects the appropriate template based on state
  - Prepares minimal assigns for the template
  - Delegates rendering to the template

  ## Architecture

      LiveComponent → Renderer (bridge) → Template → UIAdapter (components)

  ## Performance Optimization

  Renderer passes two key assigns to templates:
  - `@static` - Same reference always, LiveView skips re-render (O(1) comparison)
  - `@state` - Changes trigger re-render only for parts using dynamic fields
  """

  use Phoenix.Component

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    state = assigns[:form_state]
    if state, do: render_with_state(assigns, state), else: render_loading(assigns)
  end

  @spec render_with_state(map(), MishkaGervaz.Form.Web.State.t()) ::
          Phoenix.LiveView.Rendered.t()
  defp render_with_state(assigns, state) do
    template = state.static.template || MishkaGervaz.Form.Templates.Standard

    assigns
    |> assign(:static, state.static)
    |> assign(:state, state)
    |> assign_new(:myself, fn -> nil end)
    |> assign_new(:uploads, fn -> %{} end)
    |> template.render()
  end

  @spec render_loading(map()) :: Phoenix.LiveView.Rendered.t()
  defp render_loading(assigns) do
    state = assigns[:form_state]
    template = (state && state.static.template) || MishkaGervaz.Form.Templates.Standard
    template.render_loading(assigns)
  end
end

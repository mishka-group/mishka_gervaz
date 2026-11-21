defmodule MishkaGervaz.Test.Web.PlacedPageLive do
  @moduledoc """
  A page that places the groups of `MishkaGervaz.Test.Web.PlacedItem`'s form in its own cards:
  `:basics` in `#card-basics`, the page's own `#card-between` after it, and `:keys` in `#card-keys`.
  `#card-between` holds a button that sends the page `between`, which counts its presses in
  `#presses`. A saved record's title shows in `#saved`, whether the form holds changes in `#dirty`.
  Opened with `?id=<id>`, the form edits that record.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(params, _session, socket),
    do: {:ok, assign(socket, saved: nil, dirty?: false, presses: 0, record_id: params["id"])}

  @impl true
  def handle_event("between", _params, socket),
    do: {:noreply, update(socket, :presses, &(&1 + 1))}

  @impl true
  def handle_info({:form_dirty, "placed", dirty?}, socket),
    do: {:noreply, assign(socket, :dirty?, dirty?)}

  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.title)}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="saved">{@saved}</p>
    <p id="dirty">{to_string(@dirty?)}</p>
    <p id="presses">{@presses}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="placed"
      resource={MishkaGervaz.Test.Web.PlacedItem}
      current_user={@master}
      record_id={@record_id}
      notify_dirty={true}
    >
      <:body :let={form}>
        <section id="card-basics">
          <MishkaGervaz.Form.Web.Live.group form={form} name={:basics} />
        </section>
        <section id="card-between">
          <button type="button" phx-click="between">Between</button>
        </section>
        <section id="card-keys">
          <MishkaGervaz.Form.Web.Live.group form={form} name={:keys} />
        </section>
      </:body>
    </.live_component>
    """
  end
end

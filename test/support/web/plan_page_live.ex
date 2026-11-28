defmodule MishkaGervaz.Test.Web.PlanPageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Form.Web.Live` form of `MishkaGervaz.Test.Web.PlanItem`, mounted the
  way an admin page mounts one, with `notify_dirty`. A saved record's title shows in `#saved`, the
  error flash the form sends in `#flash-error`, and whether the form holds changes in `#dirty`.
  Opened with `?id=<id>`, the form edits that record. Its `#put-discount` button puts a discount of
  15 into the open form (`MishkaGervaz.Form.Web.Live.put_values/2`), a value the page worked out.
  Opened with `?shop=<name>`, the form's `defaults` carry the shop, live data no field reads: the
  `#rename-shop` button renames it to "<name> 2" and `#default-title` gives the title field the
  default "From the page", as a page refreshing its data while the form is open.
  Opened with `?navigation=sequential` or `?navigation=free` the form takes that navigation over
  its own, and with `?step=<name>` it opens on that tab. The tab the form tells the page it moved
  to shows in `#step`. The page adds `#pricing-extra`, reading the form's mode, to the Pricing tab
  through the form's `:in_step` slot.

  On `/plans/drawer` the form sits in the Tailwind adapter's drawer, `#plan-drawer`, open as the
  page opens. While the form holds changes the drawer asks "Discard your changes?" before it
  closes; its close sends the page `close_drawer`, which takes it away.
  """

  use Phoenix.LiveView

  alias MishkaGervaz.Helpers
  alias MishkaGervaz.UIAdapters.Tailwind
  alias Phoenix.LiveView.JS

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(params, _session, socket) do
    new_socket =
      assign(socket,
        saved: nil,
        dirty?: false,
        open?: true,
        record_id: params["id"],
        defaults: params["shop"] && %{shop: params["shop"]},
        navigation: navigation(params["navigation"]),
        step: params["step"],
        told: nil
      )

    {:ok, new_socket}
  end

  defp navigation("sequential"), do: :sequential
  defp navigation("free"), do: :free
  defp navigation(_none), do: nil

  @impl true
  def handle_event("close_drawer", _params, socket), do: {:noreply, assign(socket, :open?, false)}

  def handle_event("rename_shop", _params, socket),
    do: {:noreply, update(socket, :defaults, &%{&1 | shop: &1.shop <> " 2"})}

  def handle_event("default_title", _params, socket),
    do: {:noreply, update(socket, :defaults, &Map.put(&1, :title, "From the page"))}

  def handle_event("put_discount", _params, socket) do
    MishkaGervaz.Form.Web.Live.put_values("plan", %{discount: 15})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:put_flash, kind, message}, socket),
    do: {:noreply, put_flash(socket, kind, message)}

  def handle_info({:form_dirty, "plan", dirty?}, socket),
    do: {:noreply, assign(socket, :dirty?, dirty?)}

  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.title)}

  def handle_info({:form_step, "plan", step}, socket),
    do: {:noreply, assign(socket, step: step, told: step)}

  @impl true
  def render(%{live_action: :drawer} = assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="dirty">{to_string(@dirty?)}</p>
    <Helpers.dynamic_component
      :if={@open?}
      module={Tailwind}
      function={:drawer}
      id="plan-drawer"
      show={true}
      title="Edit plan"
      on_close={JS.push("close_drawer")}
      confirm_close={@dirty? && "Discard your changes?"}
    >
      <.live_component
        module={MishkaGervaz.Form.Web.Live}
        id="plan"
        resource={MishkaGervaz.Test.Web.PlanItem}
        current_user={@master}
        record_id={@record_id}
        notify_dirty={true}
      />
    </Helpers.dynamic_component>
    """
  end

  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="flash-error">{Phoenix.Flash.get(@flash, :error)}</p>
    <p id="saved">{@saved}</p>
    <p id="dirty">{to_string(@dirty?)}</p>
    <p id="step">{@told}</p>
    <button id="put-discount" type="button" phx-click="put_discount">Put a discount</button>
    <button id="rename-shop" type="button" phx-click="rename_shop">Rename the shop</button>
    <button id="default-title" type="button" phx-click="default_title">Default the title</button>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="plan"
      resource={MishkaGervaz.Test.Web.PlanItem}
      current_user={@master}
      record_id={@record_id}
      defaults={@defaults}
      navigation={@navigation}
      step={@step}
      notify_dirty={true}
      notify_step={true}
    >
      <:in_step :let={form} name={:pricing}>
        <p id="pricing-extra">Priced as {form.state.mode}</p>
      </:in_step>
    </.live_component>
    """
  end
end

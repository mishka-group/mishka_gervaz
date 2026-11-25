defmodule MishkaGervaz.Test.Web.RulePageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Form.Web.Live` form of `MishkaGervaz.Test.Web.RuleItem`, mounted the
  way an admin page mounts one, with `notify_failed`. A saved record's name shows in `#saved`; the
  fields of each refused save, as the form sends them in `{:form_failed, ...}`, in `#failed`, one
  line per refusal.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(_params, _session, socket) do
    new_socket = socket |> assign(:saved, nil) |> assign(:failed, [])
    {:ok, new_socket}
  end

  @impl true
  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.name)}

  def handle_info({:form_failed, "rule", %{mode: mode, fields: fields}}, socket),
    do: {:noreply, update(socket, :failed, &(&1 ++ [{mode, fields}]))}

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="saved">{@saved}</p>
    <p :for={{mode, fields} <- @failed} data-role="failed">{mode}: {Enum.join(fields, ", ")}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="rule"
      resource={MishkaGervaz.Test.Web.RuleItem}
      current_user={@master}
      notify_failed={true}
    />
    """
  end
end

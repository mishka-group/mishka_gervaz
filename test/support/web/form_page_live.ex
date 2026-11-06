defmodule MishkaGervaz.Test.Web.FormPageLive do
  @moduledoc """
  A page with one `MishkaGervaz.Form.Web.Live` form of `MishkaGervaz.Test.Web.WizardItem`, mounted
  the way an admin page mounts one. It puts the `{:put_flash, kind, message}` the form sends and
  shows the error flash in `#flash-error`; a saved record's title shows in `#saved`.
  """

  use Phoenix.LiveView

  @master %{id: "master-1", site_id: nil, role: :admin}

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :saved, nil)}

  @impl true
  def handle_info({:put_flash, kind, message}, socket),
    do: {:noreply, put_flash(socket, kind, message)}

  def handle_info({:form_saved, _mode, record}, socket),
    do: {:noreply, assign(socket, :saved, record.title)}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :master, @master)

    ~H"""
    <p id="flash-error">{Phoenix.Flash.get(@flash, :error)}</p>
    <p id="saved">{@saved}</p>
    <.live_component
      module={MishkaGervaz.Form.Web.Live}
      id="wizard"
      resource={MishkaGervaz.Test.Web.WizardItem}
      current_user={@master}
    />
    """
  end
end

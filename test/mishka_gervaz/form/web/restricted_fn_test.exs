defmodule MishkaGervaz.Form.Web.RestrictedFnTest do
  @moduledoc """
  A field's `restricted fn state -> boolean end` answers whether the field is restricted, as it
  does on a header, a notice, a submit button and a form mode: `true` hides the field and leaves it
  out of what the form saves, `false` draws and saves it.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{Events, Live, Renderer}
  alias MishkaGervaz.Test.Resources.RestrictedEntry

  @editor %{id: "user-1", site_id: nil, role: :editor}
  @viewer %{id: "user-2", site_id: nil, role: :viewer}

  setup do
    RestrictedEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp mount(user) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        %{id: "restricted-entry", resource: RestrictedEntry, current_user: user},
        socket
      )

    socket
  end

  defp render_form(socket),
    do:
      render_component(&Renderer.render/1, %{
        form_state: socket.assigns.form_state,
        __changed__: %{}
      })

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  describe "when the function says the field is restricted" do
    test "the field is not drawn" do
      html = @viewer |> mount() |> render_form()

      assert html =~ ~s|name="form[title]"|
      refute html =~ ~s|name="form[note]"|
    end

    test "a save leaves the field out" do
      @viewer |> mount() |> save(%{"title" => "T", "note" => "smuggled"})

      assert [%{title: "T", note: nil}] = Ash.read!(RestrictedEntry)
    end
  end

  describe "when the function says the field is not restricted" do
    test "the field is drawn" do
      assert @editor |> mount() |> render_form() =~ ~s|name="form[note]"|
    end

    test "a save keeps the field" do
      @editor |> mount() |> save(%{"title" => "T", "note" => "kept"})

      assert [%{title: "T", note: "kept"}] = Ash.read!(RestrictedEntry)
    end
  end
end

defmodule MishkaGervaz.Form.Web.SaveHooksTest do
  @moduledoc """
  The server hooks a save runs.

  `before_save` may return the params to save, as a bare map or as `{:cont, params}`, or
  `{:halt, reason}` to refuse the save. `after_save` runs with the saved record, and `on_error` with
  the form a failed save left, and the state it returns is the one the form shows.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{Events, Live, Renderer}
  alias MishkaGervaz.Test.Resources.{HaltedEntry, HookedEntry}

  @user %{id: "user-1", site_id: nil}

  setup do
    for resource <- [HookedEntry, HaltedEntry] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    :ok
  end

  defp mount(resource \\ HookedEntry) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(%{id: "hooked-entry", resource: resource, current_user: @user}, socket)

    socket
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{form_state: socket.assigns.form_state})
  end

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  describe "before_save" do
    test "saves the params it returns as a bare map" do
      mount() |> save(%{"title" => "hello"})

      assert [%{title: "HELLO"}] = Ash.read!(HookedEntry)
    end
  end

  describe "before_save that halts" do
    test "shows its reason above the submit row and saves nothing" do
      socket = mount(HaltedEntry) |> save(%{"title" => "stale copy"})
      state = socket.assigns.form_state
      html = render_form(socket)

      assert state.form_errors == ["This entry changed in another tab. Reload to see it."]
      assert Ash.read!(HaltedEntry) == []

      [_, after_errors] = String.split(html, ~s(id="hooked-entry-form-errors"))
      assert after_errors =~ "This entry changed in another tab. Reload to see it."
      assert after_errors =~ ~s(type="submit")
    end

    test "counts as a refused save, and moves the reader to its reason" do
      socket = mount(HaltedEntry) |> save(%{"title" => "stale copy"})

      assert socket.assigns.form_state.failed_saves == 1

      [js] =
        socket
        |> render_form()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(~s|span[id="hooked-entry-failed-save-1"]|)
        |> LazyHTML.attribute("phx-mounted")

      assert [["focus", %{"to" => "#hooked-entry-form-errors"}]] = Jason.decode!(js)
    end

    test "keeps the form open with what the user typed" do
      socket = mount(HaltedEntry) |> save(%{"title" => "stale copy"})
      state = socket.assigns.form_state

      assert state.mode == :create
      assert Phoenix.HTML.Form.input_value(state.form, :title) == "stale copy"
      assert render_form(socket) =~ ~s(value="stale copy")
    end

    test "a reason that is not a sentence says the changes were not saved" do
      socket = mount(HaltedEntry) |> save(%{"title" => "refuse"})

      assert socket.assigns.form_state.form_errors == ["The changes were not saved."]
      assert Ash.read!(HaltedEntry) == []
    end

    test "the next save that goes through clears the message" do
      socket =
        mount(HaltedEntry) |> save(%{"title" => "stale copy"}) |> save(%{"title" => "fresh"})

      assert socket.assigns.form_state.form_errors == []
      assert [%{title: "fresh"}] = Ash.read!(HaltedEntry)
    end
  end

  describe "after_save" do
    test "runs with the saved record" do
      mount() |> save(%{"title" => "hello"})

      assert_received {:after_save_hook, "HELLO"}
    end

    test "does not run when the save fails" do
      mount() |> save(%{"title" => ""})

      refute_received {:after_save_hook, _title}
    end
  end

  describe "on_error" do
    test "runs with the form a failed save left, and the form shows the state it returns" do
      socket = mount() |> save(%{"title" => ""})

      assert_received {:on_error_hook, :create}
      assert "Checked by the hook." in socket.assigns.form_state.form_errors
      assert socket.assigns.form_state.errors != %{}
    end

    test "does not run when the save succeeds" do
      mount() |> save(%{"title" => "hello"})

      refute_received {:on_error_hook, _type}
    end
  end
end

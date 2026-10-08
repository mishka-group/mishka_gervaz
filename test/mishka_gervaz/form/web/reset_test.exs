defmodule MishkaGervaz.Form.Web.ResetTest do
  @moduledoc """
  A form opened again starts over.

  A page keeps its form mounted and only hides it, so whatever was typed, every error and every
  pending upload outlive a close that sends the form nothing (a modal's close icon, Escape, a click
  outside it). Opening it again — the `reset` event a create opener pushes, or `reset: true` beside a
  `record_id`, which a table's Edit sends — starts it over: a create on the empty create form with its
  defaults, an edit on the record read again. A create is drawn without its `<form>` first and built
  by the `send_update/2` that follows, so every control is drawn anew.

  A form started over, by a reset or by Cancel, keeps the options a plain `:static` select read when
  the form was mounted.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Live, Renderer}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader

  alias MishkaGervaz.Test.Resources.{
    PickerEntry,
    PickerRegion,
    PickerStaticEntry,
    PickerVersion,
    PickerWorkspace
  }

  @user %{id: "user-1", site_id: nil}
  @id "picker-entry"

  setup do
    for resource <- [PickerEntry, PickerStaticEntry, PickerVersion, PickerWorkspace, PickerRegion] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    flush_send_updates()

    entry = Ash.create!(PickerEntry, %{title: "Saved title", version_id: Ash.UUID.generate()})
    %{entry: entry}
  end

  defp flush_send_updates do
    receive do
      {:phoenix, :send_update, _update} -> flush_send_updates()
    after
      0 -> :ok
    end
  end

  defp mount(assigns \\ %{}) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        Map.merge(%{id: @id, resource: PickerEntry, current_user: @user}, assigns),
        socket
      )

    socket
  end

  defp mount_static_entry do
    north = Ash.create!(PickerRegion, %{name: "North"})

    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(%{id: @id, resource: PickerStaticEntry, current_user: @user}, socket)

    options = socket.assigns.form_state.relation_options

    assert %{region_id: %{options: [{"North", region_id}]}} = options
    assert region_id == north.id

    {socket, options}
  end

  defp component_update(socket, assigns) do
    {:ok, socket} = Live.update(Map.put(assigns, :id, @id), socket)
    socket
  end

  defp deliver_send_updates(socket) do
    receive do
      {:phoenix, :send_update, {{Live, @id}, assigns}} ->
        socket |> component_update(assigns) |> deliver_send_updates()
    after
      0 -> socket
    end
  end

  defp type(socket, field, value) do
    params = %{"form" => %{field => value}, "_target" => ["form", field]}
    {:noreply, socket} = Events.handle("validate", params, socket)
    socket
  end

  defp save(socket) do
    params = %{"form" => socket.assigns.form_state.form.params}
    {:noreply, socket} = Events.handle("save", params, socket)
    socket
  end

  defp cancel(socket) do
    {:noreply, socket} = Events.handle("cancel", %{}, socket)
    socket
  end

  defp push_reset(socket) do
    {:noreply, socket} = Events.handle("reset", %{}, socket)
    socket
  end

  defp open_create(socket) do
    socket = push_reset(socket)

    assert socket.assigns.form_state.form == nil

    deliver_send_updates(socket)
  end

  defp open_edit(socket, entry) do
    socket = component_update(socket, %{record_id: entry.id, reset: true})
    finish_loading(socket, entry)
  end

  defp finish_loading(socket, entry) do
    state = socket.assigns.form_state
    {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)
    DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{
      form_state: socket.assigns.form_state,
      __changed__: %{}
    })
  end

  defp title(socket),
    do: Phoenix.HTML.Form.input_value(socket.assigns.form_state.form, :title)

  defp assert_empty_create(socket) do
    state = socket.assigns.form_state

    assert socket.assigns.record_id == nil
    assert state.mode == :create
    assert state.loading == :loaded
    assert state.form.source.type == :create
    assert state.form.params == %{}
    assert state.form.source.submitted_once? == false
    assert state.errors == %{}
    assert state.form_errors == []
    assert state.dirty? == false
    assert state.field_values == %{}
    assert title(socket) in [nil, ""]
  end

  describe "a create opened again" do
    test "after typing and a close that sends the form nothing, is the empty create form" do
      socket = mount() |> type("title", "Half typed") |> open_create()

      assert_empty_create(socket)
    end

    test "after a failed save, drops the typed values and the errors" do
      socket = mount() |> type("title", "Missing a version") |> save()

      assert socket.assigns.form_state.errors != %{}

      socket = open_create(socket)

      assert_empty_create(socket)
    end

    test "after typing and Cancel, is the empty create form" do
      socket = mount() |> type("title", "Half typed") |> cancel() |> open_create()

      assert_empty_create(socket)
    end

    test "is drawn without its form first, then with the empty one" do
      socket = mount() |> type("title", "Half typed") |> push_reset()

      assert socket.assigns.form_state.form == nil
      refute render_form(socket) =~ "<form"
      assert_received {:phoenix, :send_update, {{Live, @id}, assigns}}

      socket = component_update(socket, assigns)

      assert_empty_create(socket)
      assert render_form(socket) =~ "<form"
    end

    test "after an edit that was cancelled, is the empty create form", %{entry: entry} do
      socket =
        mount()
        |> open_edit(entry)
        |> type("title", "Changed")
        |> cancel()
        |> open_create()

      assert_empty_create(socket)
    end

    test "after an edit closed without saving, is the empty create form", %{entry: entry} do
      socket = mount() |> open_edit(entry) |> type("title", "Changed") |> open_create()

      assert_empty_create(socket)
    end

    test "keeps the page's defaults" do
      version_id = Ash.UUID.generate()
      defaults = %{version_id: version_id}

      socket = %{defaults: defaults} |> mount() |> type("title", "Half typed") |> open_create()

      state = socket.assigns.form_state
      assert state.defaults == defaults
      assert state.field_values == %{version_id: version_id}
      assert title(socket) in [nil, ""]
    end

    test "keeps a plain select's options" do
      {socket, options} = mount_static_entry()

      socket = socket |> type("title", "Half typed") |> open_create()

      assert socket.assigns.form_state.relation_options.region_id == options.region_id
    end

    test "after Cancel, a plain select keeps its options" do
      {socket, options} = mount_static_entry()

      socket = socket |> type("title", "Half typed") |> cancel()

      assert socket.assigns.form_state.relation_options.region_id == options.region_id
    end

    test "with send_update and reset: true, as a page's own opener sends it" do
      socket =
        mount()
        |> type("title", "Half typed")
        |> component_update(%{record_id: nil, reset: true})

      assert socket.assigns.form_state.form == nil

      socket = deliver_send_updates(socket)

      assert_empty_create(socket)
    end

    test "stays on the record an Edit opened before the empty form was built", %{entry: entry} do
      socket = mount() |> type("title", "Half typed") |> push_reset()

      assert_received {:phoenix, :send_update, {{Live, @id}, build}}

      socket = socket |> open_edit(entry) |> component_update(build)

      assert socket.assigns.record_id == entry.id
      assert socket.assigns.form_state.mode == :update
      assert title(socket) == "Saved title"
    end
  end

  describe "an edit opened again" do
    test "after a create that was cancelled, loads the record", %{entry: entry} do
      socket = mount() |> type("title", "Half typed") |> cancel() |> open_edit(entry)

      assert socket.assigns.record_id == entry.id
      assert socket.assigns.form_state.mode == :update
      assert title(socket) == "Saved title"
    end

    test "after a create closed without saving, loads the record", %{entry: entry} do
      socket = mount() |> type("title", "Half typed") |> open_edit(entry)

      assert socket.assigns.record_id == entry.id
      assert socket.assigns.form_state.mode == :update
      assert title(socket) == "Saved title"
    end

    test "on the record it was closed on, reads it again", %{entry: entry} do
      socket = mount() |> open_edit(entry) |> type("title", "Unsaved change")

      assert title(socket) == "Unsaved change"

      socket = component_update(socket, %{record_id: entry.id, reset: true})

      assert socket.assigns.form_state.loading == :loading
      assert socket.assigns.form_state.form == nil

      socket = finish_loading(socket, entry)

      assert socket.assigns.form_state.dirty? == false
      assert title(socket) == "Saved title"
    end
  end

  test "a table's Edit asks the form to start over on the record" do
    state = %{static: %{resource: PickerEntry}}
    id = Ash.UUID.generate()

    MishkaGervaz.Table.Web.Events.do_edit(state, %{"id" => id}, %Phoenix.LiveView.Socket{})

    assert_received {:phoenix, :send_update,
                     {{Live, "picker_entry"}, %{id: "picker_entry", record_id: ^id, reset: true}}}
  end

  test "reset/2 pushes the reset event to the form" do
    js = Live.reset(@id)

    assert js.ops == [["push", %{event: "reset", target: "#picker-entry-form-wrapper"}]]
  end
end

defmodule MishkaGervaz.Form.Web.AfterSaveTest do
  @moduledoc """
  Where the form is after a save.

  A form mounted with a `record_id` follows it: an update save leaves it on the saved record. A form
  opened for editing with `send_update/2` returns to an empty create form, and so does every create
  save. A record that finishes loading after the form has returned to create is ignored.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1, build_socket: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Live, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Test.Resources.{PickerEntry, PickerRegion, PickerVersion, PickerWorkspace}

  @user %{id: "user-1", site_id: nil}

  setup do
    for resource <- [PickerEntry, PickerVersion, PickerWorkspace, PickerRegion] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    version_id = Ash.UUID.generate()
    %{entry: Ash.create!(PickerEntry, %{title: "Entry", version_id: version_id})}
  end

  defp editing(entry, assigns) do
    state = "picker-entry" |> State.init(PickerEntry, @user) |> State.update(mode: :update)
    {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)

    DataLoader.Default.handle_async_result(
      :load_record,
      {:ok, {:ok, form}},
      build_socket(state, assigns: Map.put(assigns, :record_id, entry.id))
    )
  end

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  describe "an update save" do
    test "on a form mounted with a record_id, stays on the saved record", %{entry: entry} do
      socket = entry |> editing(%{record_id_given?: true}) |> save(%{"title" => "Renamed"})

      assert_received {:form_saved, :update, %{title: "Renamed"}}
      assert socket.assigns.record_id == entry.id
      assert socket.assigns.form_state.mode == :update
      assert socket.assigns.form_state.loading == :loading

      state = socket.assigns.form_state
      {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)

      socket = DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      assert socket.assigns.form_state.loading == :loaded
      assert socket.assigns.form_state.form.source.type == :update
      assert socket.assigns.form_state.form.source.data.title == "Renamed"
    end

    test "on a form opened with send_update, returns to an empty create form", %{entry: entry} do
      socket = entry |> editing(%{}) |> save(%{"title" => "Renamed"})

      assert_received {:form_saved, :update, _record}
      assert socket.assigns.record_id == nil
      assert socket.assigns.form_state.mode == :create
      assert socket.assigns.form_state.form.source.type == :create
    end
  end

  test "a create save returns to an empty create form, whatever the mount" do
    state = State.init("picker-entry", PickerEntry, @user)

    socket =
      state
      |> build_socket(assigns: %{record_id: nil, record_id_given?: true})
      |> DataLoader.new_record(state)
      |> save(%{"title" => "New", "version_id" => Ash.UUID.generate()})

    assert_received {:form_saved, :create, _record}
    assert socket.assigns.form_state.mode == :create
    assert socket.assigns.form_state.form.source.type == :create
  end

  test "a record that finishes loading after the form returned to create is ignored", %{
    entry: entry
  } do
    state = State.init("picker-entry", PickerEntry, @user)
    socket = DataLoader.new_record(build_socket(state), state)
    create_state = socket.assigns.form_state

    {:ok, form} =
      RecordLoader.Default.load_for_edit(State.update(create_state, mode: :update), entry.id,
        actor: @user
      )

    socket = DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

    assert socket.assigns.form_state == create_state
  end

  describe "mounting" do
    defp mount(assigns) do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}

      {:ok, socket} =
        Live.update(
          Map.merge(%{id: "picker-entry", resource: PickerEntry, current_user: @user}, assigns),
          socket
        )

      socket
    end

    test "with a record_id, even nil, the form follows it" do
      assert mount(%{record_id: nil}).assigns.record_id_given?
    end

    test "without one, it does not" do
      refute mount(%{}).assigns.record_id_given?
    end
  end
end

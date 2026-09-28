defmodule MishkaGervaz.Form.Web.Events.DependentPickersTest do
  @moduledoc """
  A picker that depends on another one is emptied when that one changes, and what it held is never
  saved.

  `MishkaGervaz.Test.Resources.PickerEntry` chains three pickers: region, workspace (depends on
  region) and the required version (depends on workspace). Each case drives the form's own events
  — `relation_select`, `relation_clear`, `field_change`, `save` — and checks what reaches the
  record.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Test.Resources.{PickerEntry, PickerRegion, PickerVersion, PickerWorkspace}

  @user %{id: "user-1", role: :admin}

  setup do
    for resource <- [PickerEntry, PickerVersion, PickerWorkspace, PickerRegion] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    north = Ash.create!(PickerRegion, %{name: "North"})
    south = Ash.create!(PickerRegion, %{name: "South"})
    w1 = Ash.create!(PickerWorkspace, %{name: "W1", region_id: north.id})
    w2 = Ash.create!(PickerWorkspace, %{name: "W2", region_id: north.id})
    w3 = Ash.create!(PickerWorkspace, %{name: "W3", region_id: south.id})
    v1 = Ash.create!(PickerVersion, %{name: "V1", workspace_id: w1.id})
    v2 = Ash.create!(PickerVersion, %{name: "V2", workspace_id: w2.id})

    %{north: north, south: south, w1: w1, w2: w2, w3: w3, v1: v1, v2: v2}
  end

  defp create_form do
    state = State.init("picker-entry", PickerEntry, @user)
    DataLoader.new_record(build_socket(state), state)
  end

  defp edit_form(entry) do
    state = "picker-entry" |> State.init(PickerEntry, @user) |> State.update(mode: :update)
    {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)
    DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, build_socket(state))
  end

  defp select(socket, field, record) do
    params = %{"filter" => to_string(field), "id" => record.id, "label" => record.name}
    {:noreply, socket} = Events.handle("relation_select", params, socket)
    socket
  end

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  defp form_param(socket, field) do
    socket.assigns.form_state.form.source
    |> AshPhoenix.Form.params()
    |> Map.fetch(to_string(field))
  end

  defp stored, do: Ash.read!(PickerEntry)

  describe "creating" do
    test "a version picked under one workspace is not saved once the workspace changes", ctx do
      socket =
        create_form()
        |> select(:region_id, ctx.north)
        |> select(:workspace_id, ctx.w1)
        |> select(:version_id, ctx.v1)
        |> select(:workspace_id, ctx.w2)

      refute Map.has_key?(socket.assigns.form_state.field_values, :version_id)
      assert form_param(socket, :version_id) == {:ok, nil}

      socket = save(socket, %{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
      assert Map.has_key?(socket.assigns.form_state.errors, :version_id)
    end

    test "the version picked under the new workspace is the one saved", ctx do
      create_form()
      |> select(:region_id, ctx.north)
      |> select(:workspace_id, ctx.w1)
      |> select(:version_id, ctx.v1)
      |> select(:workspace_id, ctx.w2)
      |> select(:version_id, ctx.v2)
      |> save(%{"title" => "Entry"})

      assert_received {:form_saved, :create, saved}
      assert saved.workspace_id == ctx.w2.id
      assert saved.version_id == ctx.v2.id
    end

    test "a region change empties the workspace and the version under it", ctx do
      socket =
        create_form()
        |> select(:region_id, ctx.north)
        |> select(:workspace_id, ctx.w1)
        |> select(:version_id, ctx.v1)
        |> select(:region_id, ctx.south)

      state = socket.assigns.form_state

      assert state.field_values == %{region_id: ctx.south.id}
      assert form_param(socket, :workspace_id) == {:ok, nil}
      assert form_param(socket, :version_id) == {:ok, nil}
      assert state.relation_options.workspace_id.loading?
      refute state.relation_options.version_id.loading?

      save(socket, %{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
    end

    test "choosing the picked version again empties it, and it is not saved", ctx do
      socket =
        create_form()
        |> select(:region_id, ctx.north)
        |> select(:workspace_id, ctx.w1)
        |> select(:version_id, ctx.v1)
        |> select(:version_id, ctx.v1)

      assert form_param(socket, :version_id) == {:ok, nil}

      save(socket, %{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
    end

    test "clearing the workspace empties it and the version under it", ctx do
      socket =
        create_form()
        |> select(:region_id, ctx.north)
        |> select(:workspace_id, ctx.w1)
        |> select(:version_id, ctx.v1)

      {:noreply, socket} = Events.handle("relation_clear", %{"filter" => "workspace_id"}, socket)

      assert socket.assigns.form_state.field_values == %{region_id: ctx.north.id}
      assert form_param(socket, :workspace_id) == {:ok, nil}
      assert form_param(socket, :version_id) == {:ok, nil}

      save(socket, %{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
    end

    test "a workspace set through field_change empties the version under the old one", ctx do
      socket =
        create_form()
        |> select(:region_id, ctx.north)
        |> select(:workspace_id, ctx.w1)
        |> select(:version_id, ctx.v1)

      {:noreply, socket} =
        Events.handle("field_change", %{"field" => "workspace_id", "value" => ctx.w2.id}, socket)

      refute Map.has_key?(socket.assigns.form_state.field_values, :version_id)
      assert form_param(socket, :version_id) == {:ok, nil}

      save(socket, %{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
    end
  end

  describe "editing" do
    setup ctx do
      entry =
        Ash.create!(PickerEntry, %{
          title: "Entry",
          region_id: ctx.north.id,
          workspace_id: ctx.w1.id,
          version_id: ctx.v1.id
        })

      %{entry: entry}
    end

    test "a workspace change with no new version is refused, not saved with the old version",
         ctx do
      socket =
        ctx.entry
        |> edit_form()
        |> select(:workspace_id, ctx.w2)
        |> save(%{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert Map.has_key?(socket.assigns.form_state.errors, :version_id)

      assert [%{workspace_id: workspace_id, version_id: version_id}] = stored()
      assert {workspace_id, version_id} == {ctx.w1.id, ctx.v1.id}
    end

    test "a workspace change with a new version saves both", ctx do
      ctx.entry
      |> edit_form()
      |> select(:workspace_id, ctx.w2)
      |> select(:version_id, ctx.v2)
      |> save(%{"title" => "Entry"})

      assert_received {:form_saved, :update, saved}
      assert {saved.workspace_id, saved.version_id} == {ctx.w2.id, ctx.v2.id}
    end
  end
end

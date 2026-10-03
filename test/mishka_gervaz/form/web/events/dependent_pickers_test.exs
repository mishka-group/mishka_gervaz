defmodule MishkaGervaz.Form.Web.Events.DependentPickersTest do
  @moduledoc """
  A picker that depends on another one is emptied when that one changes, and what it held is never
  saved.

  `MishkaGervaz.Test.Resources.PickerEntry` chains three pickers: region, workspace (depends on
  region) and the required version (depends on workspace). A form mounted with `defaults` opens on
  them. `MishkaGervaz.Test.Resources.PickerScopedEntry` hangs a picker under a multi-select and one
  under a combobox. Each case drives the form's own events — `relation_select`, `relation_toggle`,
  `relation_clear`, `combobox_select`, `field_change`, `save` — and checks what reaches the record.

  `MishkaGervaz.Test.Resources.PickerLockedEntry` hangs the same chain under a region only a master
  may set, read-only when the mount gives it: an event sent for that region changes nothing.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader

  alias MishkaGervaz.Test.Resources.{
    PickerEntry,
    PickerLockedEntry,
    PickerRegion,
    PickerScopedEntry,
    PickerVersion,
    PickerWorkspace
  }

  @user %{id: "user-1", role: :admin}
  @master %{id: "master-1", site_id: nil}
  @site_user %{id: "user-2", site_id: "0c8e5d0e-7c8c-4b8f-9d2a-4a4b1c1f0d11"}

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

  defp create_form(defaults \\ nil) do
    state = "picker-entry" |> State.init(PickerEntry, @user) |> State.update(defaults: defaults)
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

  describe "creating with defaults" do
    setup ctx do
      %{defaults: %{region_id: ctx.north.id, workspace_id: ctx.w1.id, version_id: ctx.v1.id}}
    end

    test "the version given as a default is not saved once the workspace changes", ctx do
      socket =
        ctx.defaults
        |> create_form()
        |> select(:workspace_id, ctx.w2)
        |> save(%{"title" => "Entry", "version_id" => ""})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
      assert Map.has_key?(socket.assigns.form_state.errors, :version_id)
    end

    test "the workspace and version given as defaults are not saved once the region changes",
         ctx do
      socket =
        ctx.defaults
        |> create_form()
        |> select(:region_id, ctx.south)
        |> save(%{"title" => "Entry"})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
      assert Map.has_key?(socket.assigns.form_state.errors, :version_id)
    end

    test "a version given as a default and then cleared is not saved", ctx do
      socket = create_form(ctx.defaults)

      {:noreply, socket} = Events.handle("relation_clear", %{"filter" => "version_id"}, socket)
      socket = save(socket, %{"title" => "Entry", "version_id" => ""})

      refute_received {:form_saved, _mode, _record}
      assert stored() == []
      assert Map.has_key?(socket.assigns.form_state.errors, :version_id)
    end

    test "the version picked under the new workspace is saved", ctx do
      ctx.defaults
      |> create_form()
      |> select(:workspace_id, ctx.w2)
      |> select(:version_id, ctx.v2)
      |> save(%{"title" => "Entry"})

      assert_received {:form_saved, :create, saved}

      assert {saved.region_id, saved.workspace_id, saved.version_id} ==
               {ctx.north.id, ctx.w2.id, ctx.v2.id}
    end

    test "defaults no picker has moved from are saved", ctx do
      ctx.defaults
      |> create_form()
      |> save(%{"title" => "Entry", "version_id" => ""})

      assert_received {:form_saved, :create, saved}

      assert {saved.region_id, saved.workspace_id, saved.version_id} ==
               {ctx.north.id, ctx.w1.id, ctx.v1.id}
    end

    test "after a save the next form saves the defaults again", ctx do
      socket =
        ctx.defaults
        |> create_form()
        |> select(:workspace_id, ctx.w2)
        |> select(:version_id, ctx.v2)
        |> save(%{"title" => "First"})

      assert_received {:form_saved, :create, _first}

      save(socket, %{"title" => "Second", "version_id" => ""})

      assert_received {:form_saved, :create, second}
      assert {second.workspace_id, second.version_id} == {ctx.w1.id, ctx.v1.id}
    end
  end

  describe "a multi-select or combobox parent" do
    setup do
      PickerScopedEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
      :ok
    end

    defp scoped_form do
      state = State.init("picker-scoped-entry", PickerScopedEntry, @user)
      DataLoader.new_record(build_socket(state), state)
    end

    defp toggle(socket, field, record) do
      params = %{"filter" => to_string(field), "id" => record.id, "label" => record.name}
      {:noreply, socket} = Events.handle("relation_toggle", params, socket)
      socket
    end

    defp combobox(socket, field, value) do
      params = %{"field" => to_string(field), "value" => value}
      {:noreply, socket} = Events.handle("combobox_select", params, socket)
      socket
    end

    test "a workspace picked under a region is not saved once that region is toggled off", ctx do
      socket =
        scoped_form()
        |> toggle(:region_ids, ctx.north)
        |> toggle(:region_ids, ctx.south)
        |> select(:workspace_id, ctx.w1)
        |> toggle(:region_ids, ctx.north)

      assert socket.assigns.form_state.field_values == %{region_ids: [ctx.south.id]}
      assert form_param(socket, :workspace_id) == {:ok, nil}

      save(socket, %{"title" => "Entry"})

      assert_received {:form_saved, :create, saved}
      assert {saved.region_ids, saved.workspace_id} == {[ctx.south.id], nil}
    end

    test "a multi-select toggled down to nothing saves an empty list", ctx do
      socket =
        scoped_form()
        |> toggle(:region_ids, ctx.north)
        |> toggle(:region_ids, ctx.north)

      assert form_param(socket, :region_ids) == {:ok, []}

      save(socket, %{"title" => "Entry"})

      assert_received {:form_saved, :create, saved}
      assert saved.region_ids == []
    end

    test "an entry opened for editing knows the labels of what its multi-select holds", ctx do
      entry = Ash.create!(PickerScopedEntry, %{title: "Kept", region_ids: [ctx.north.id]})

      state =
        "picker-scoped-entry"
        |> State.init(PickerScopedEntry, @user)
        |> State.update(mode: :update)

      {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)

      socket =
        DataLoader.Default.handle_async_result(
          :load_record,
          {:ok, {:ok, form}},
          build_socket(state)
        )

      assert socket.assigns.form_state.relation_options.region_ids.selected_options ==
               [{"North", ctx.north.id}]
    end

    test "a version picked under one language is not saved once the language changes", ctx do
      socket =
        scoped_form()
        |> combobox(:language, "en")
        |> select(:version_id, ctx.v1)
        |> combobox(:language, "fa")

      assert socket.assigns.form_state.field_values == %{language: "fa"}
      assert form_param(socket, :version_id) == {:ok, nil}

      save(socket, %{"title" => "Entry", "language" => "fa"})

      assert_received {:form_saved, :create, saved}
      assert {saved.language, saved.version_id} == {"fa", nil}
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

    test "each search picker knows the label of what it holds, and a click away keeps it", ctx do
      socket = edit_form(ctx.entry)

      {:noreply, socket} =
        Events.handle("relation_close_dropdown", %{"filter" => "workspace_id"}, socket)

      options = socket.assigns.form_state.relation_options

      assert {options.region_id.selected_options, options.workspace_id.selected_options,
              options.version_id.selected_options} ==
               {[{"North", ctx.north.id}], [{"W1", ctx.w1.id}], [{"V1", ctx.v1.id}]}

      assert options.workspace_id.options == []
    end
  end

  describe "a parent the user may not change" do
    setup ctx do
      PickerLockedEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)

      region_events = [
        {"relation_select", %{"filter" => "region_id", "id" => ctx.south.id, "label" => "South"}},
        {"relation_toggle", %{"filter" => "region_id", "id" => ctx.south.id, "label" => "South"}},
        {"relation_clear", %{"filter" => "region_id"}},
        {"combobox_select", %{"field" => "region_id", "value" => ctx.south.id}},
        {"field_change", %{"field" => "region_id", "value" => ctx.south.id}}
      ]

      %{
        region_events: region_events,
        defaults: %{region_id: ctx.north.id, workspace_id: ctx.w1.id, version_id: ctx.v1.id}
      }
    end

    defp locked_form(user, defaults) do
      state =
        "picker-locked-entry"
        |> State.init(PickerLockedEntry, user)
        |> State.update(defaults: defaults)

      DataLoader.new_record(build_socket(state), state)
    end

    defp send_event(socket, event, params) do
      {:noreply, socket} = Events.handle(event, params, socket)
      socket
    end

    defp saved_chain do
      assert_received {:form_saved, :create, saved}
      {saved.region_id, saved.workspace_id, saved.version_id}
    end

    test "every event for a region the page gave changes nothing, and the defaults are saved",
         ctx do
      for {event, params} <- ctx.region_events do
        opened = locked_form(@master, ctx.defaults)
        socket = send_event(opened, event, params)

        assert socket.assigns.form_state.field_values == opened.assigns.form_state.field_values,
               "#{event} changed the pickers under a read-only region"

        save(socket, %{"title" => event})

        assert saved_chain() == {ctx.north.id, ctx.w1.id, ctx.v1.id},
               "#{event} kept the defaults out of the save"
      end
    end

    test "every event a site user sends for a master-only region changes nothing", ctx do
      defaults = Map.delete(ctx.defaults, :region_id)

      for {event, params} <- ctx.region_events do
        opened = locked_form(@site_user, defaults)
        socket = send_event(opened, event, params)

        assert socket.assigns.form_state.field_values == opened.assigns.form_state.field_values,
               "#{event} changed the pickers under a master-only region"

        save(socket, %{"title" => event})

        assert saved_chain() == {nil, ctx.w1.id, ctx.v1.id},
               "#{event} kept the defaults out of the save"
      end
    end

    test "the same events for a region a master may change empty the pickers under it", ctx do
      defaults = Map.delete(ctx.defaults, :region_id)

      for {event, params} <- ctx.region_events do
        socket = @master |> locked_form(defaults) |> send_event(event, params)
        field_values = socket.assigns.form_state.field_values

        refute Map.has_key?(field_values, :workspace_id), "#{event} left the workspace"
        refute Map.has_key?(field_values, :version_id), "#{event} left the version"
      end
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.RelationValuesAcrossValidateTest do
  @moduledoc """
  What a relation picker holds stays on the form when another field changes, and a save keeps it.

  `MishkaGervaz.Test.Resources.PickerCoveredEntry` picks its regions in the `:search_multi` field
  `:region_ids`, saved through a many-to-many, and one workspace in the `:search` field
  `:workspace_id`. `MishkaGervaz.Test.Resources.PickerScopedEntry` hangs a picker under a
  multi-select. Each case drives the form's own events with what the rendered form posts, as a
  browser does, and checks the rendered form and what reaches the record.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Renderer, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader

  alias MishkaGervaz.Test.Resources.{
    PickerCoverage,
    PickerCoveredEntry,
    PickerRegion,
    PickerScopedEntry,
    PickerWorkspace,
    StringListForm
  }

  @user %{id: "user-1", role: :admin}

  setup do
    for resource <- [PickerCoverage, PickerCoveredEntry, PickerScopedEntry, PickerWorkspace] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    PickerRegion |> Ash.read!() |> Enum.each(&Ash.destroy!/1)

    north = Ash.create!(PickerRegion, %{name: "North"})
    south = Ash.create!(PickerRegion, %{name: "South"})
    east = Ash.create!(PickerRegion, %{name: "East"})
    w1 = Ash.create!(PickerWorkspace, %{name: "W1", region_id: north.id})

    %{north: north, south: south, east: east, w1: w1}
  end

  defp edit_form(entry) do
    state =
      "picker-covered-entry"
      |> State.init(PickerCoveredEntry, @user)
      |> State.update(mode: :update)

    {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)
    DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, build_socket(state))
  end

  defp create_form(id, resource, defaults \\ nil) do
    state = id |> State.init(resource, @user) |> State.update(defaults: defaults)
    DataLoader.new_record(build_socket(state), state)
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{
      form_state: socket.assigns.form_state,
      __changed__: %{}
    })
  end

  defp posted(socket, form_params) do
    hidden =
      ~r/<input type="hidden" name="([^"]+)" value="([^"]*)"/
      |> Regex.scan(render_form(socket), capture: :all_but_first)
      |> Enum.reject(fn [name, _value] -> String.starts_with?(name, "form[") end)
      |> Enum.map(fn [name, value] -> {name, value} end)

    typed = Enum.map(form_params, fn {key, value} -> {"form[#{key}]", value} end)

    (hidden ++ typed)
    |> URI.encode_query()
    |> Plug.Conn.Query.decode()
  end

  defp validate(socket, form_params) do
    params = socket |> posted(form_params) |> Map.put("_target", ["form", "title"])
    {:noreply, socket} = Events.handle("validate", params, socket)
    socket
  end

  defp save(socket, form_params) do
    {:noreply, socket} = Events.handle("save", posted(socket, form_params), socket)
    socket
  end

  defp toggle(socket, field, record) do
    params = %{"filter" => to_string(field), "id" => record.id, "label" => record.name}
    {:noreply, socket} = Events.handle("relation_toggle", params, socket)
    socket
  end

  defp finish_loading(socket, field_name) do
    state = socket.assigns.form_state
    field = Enum.find(state.static.fields, &(&1.name == field_name))
    result = DataLoader.Default.relation_loader().load_options(field, state)
    DataLoader.Default.handle_async_result({:load_relation, field_name}, {:ok, result}, socket)
  end

  defp shown_regions(socket) do
    ~r/<input type="hidden" name="region_ids\[\]" value="([^"]+)"/
    |> Regex.scan(render_form(socket), capture: :all_but_first)
    |> List.flatten()
    |> Enum.sort()
  end

  defp shown_workspace(socket) do
    ~r/<input type="hidden" name="workspace_id" value="([^"]*)"/
    |> Regex.run(render_form(socket), capture: :all_but_first)
    |> List.wrap()
    |> List.first()
  end

  defp stored_regions(entry_id) do
    PickerCoveredEntry
    |> Ash.get!(entry_id, load: :regions)
    |> Map.fetch!(:regions)
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  defp ids(records), do: records |> Enum.map(& &1.id) |> Enum.sort()

  describe "editing an entry that covers regions" do
    setup ctx do
      entry =
        Ash.create!(PickerCoveredEntry, %{
          title: "Entry",
          workspace_id: ctx.w1.id,
          region_ids: [ctx.north.id, ctx.south.id]
        })

      %{entry: entry}
    end

    test "the form opens with the regions and the workspace the entry has", ctx do
      socket = edit_form(ctx.entry)

      assert shown_regions(socket) == ids([ctx.north, ctx.south])
      assert shown_workspace(socket) == ctx.w1.id
    end

    test "a change to another field keeps the regions and the workspace on the form", ctx do
      socket = ctx.entry |> edit_form() |> validate(%{"title" => "Renamed"})
      html = render_form(socket)

      assert shown_regions(socket) == ids([ctx.north, ctx.south])
      assert html =~ ~s(aria-label="Remove North")
      assert html =~ ~s(aria-label="Remove South")
      assert shown_workspace(socket) == ctx.w1.id
    end

    test "the change carries the regions in the form's params", ctx do
      socket = ctx.entry |> edit_form() |> validate(%{"title" => "Renamed"})

      {:ok, region_ids} =
        socket.assigns.form_state.form.source
        |> AshPhoenix.Form.params()
        |> Map.fetch("region_ids")

      assert Enum.sort(region_ids) == ids([ctx.north, ctx.south])
    end

    test "a save after that change keeps the regions", ctx do
      ctx.entry
      |> edit_form()
      |> validate(%{"title" => "Renamed"})
      |> save(%{"title" => "Renamed"})

      assert_received {:form_saved, :update, %{title: "Renamed"}}
      assert stored_regions(ctx.entry.id) == ids([ctx.north, ctx.south])
    end

    test "a region added after that change is saved beside the ones the entry had", ctx do
      socket =
        ctx.entry
        |> edit_form()
        |> validate(%{"title" => "Renamed"})
        |> toggle(:region_ids, ctx.east)

      assert shown_regions(socket) == ids([ctx.north, ctx.south, ctx.east])

      save(socket, %{"title" => "Renamed"})

      assert_received {:form_saved, :update, _entry}
      assert stored_regions(ctx.entry.id) == ids([ctx.north, ctx.south, ctx.east])
    end

    test "a region removed before a change to another field stays removed", ctx do
      socket =
        ctx.entry
        |> edit_form()
        |> toggle(:region_ids, ctx.north)
        |> validate(%{"title" => "Renamed"})

      assert shown_regions(socket) == [ctx.south.id]
      refute render_form(socket) =~ ~s(aria-label="Remove North")

      save(socket, %{"title" => "Renamed"})

      assert_received {:form_saved, :update, _entry}
      assert stored_regions(ctx.entry.id) == [ctx.south.id]
    end

    test "every region removed before a change to another field is saved as none", ctx do
      socket =
        ctx.entry
        |> edit_form()
        |> toggle(:region_ids, ctx.north)
        |> toggle(:region_ids, ctx.south)
        |> validate(%{"title" => "Renamed"})

      assert shown_regions(socket) == []

      save(socket, %{"title" => "Renamed"})

      assert_received {:form_saved, :update, _entry}
      assert stored_regions(ctx.entry.id) == []
    end
  end

  describe "creating" do
    test "regions picked on a new entry stay on the form through a change, and are saved", ctx do
      socket =
        "picker-covered-entry"
        |> create_form(PickerCoveredEntry)
        |> toggle(:region_ids, ctx.north)
        |> toggle(:region_ids, ctx.east)
        |> validate(%{"title" => "New"})

      assert shown_regions(socket) == ids([ctx.north, ctx.east])

      save(socket, %{"title" => "New"})

      assert_received {:form_saved, :create, saved}
      assert stored_regions(saved.id) == ids([ctx.north, ctx.east])
    end

    test "regions given as defaults stay on the form through a change, and are saved", ctx do
      socket =
        "picker-covered-entry"
        |> create_form(PickerCoveredEntry, %{region_ids: [ctx.north.id]})
        |> validate(%{"title" => "New"})

      assert shown_regions(socket) == [ctx.north.id]

      save(socket, %{"title" => "New"})

      assert_received {:form_saved, :create, saved}
      assert stored_regions(saved.id) == [ctx.north.id]
    end

    test "a picker under a multi-select stays open after a change to another field", ctx do
      socket =
        "picker-scoped-entry"
        |> create_form(PickerScopedEntry)
        |> toggle(:region_ids, ctx.north)
        |> finish_loading(:workspace_id)

      assert render_form(socket) =~ ~s(name="_search_workspace_id")

      html = socket |> validate(%{"title" => "New"}) |> render_form()

      assert html =~ ~s(name="_search_workspace_id")
      refute html =~ ~r/Select Region ids first/i
    end
  end

  describe "a string list" do
    test "a change to the form draws the items typed, not the ones the add button left" do
      socket = create_form("string-list-form", StringListForm)
      {:noreply, socket} = Events.handle("add_list_item", %{"field" => "tags"}, socket)

      assert socket.assigns.form_state.field_values.tags == [""]

      params = %{
        "form" => %{"title" => "T", "tags" => ["alpha", "beta"]},
        "_target" => ["form", "tags"]
      }

      {:noreply, socket} = Events.handle("validate", params, socket)
      html = render_form(socket)

      refute Map.has_key?(socket.assigns.form_state.field_values, :tags)
      assert html =~ ~s(value="alpha")
      assert html =~ ~s(value="beta")
    end
  end
end

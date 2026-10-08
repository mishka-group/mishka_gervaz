defmodule MishkaGervaz.Form.Web.Events.StaticRelationPicksTest do
  @moduledoc """
  A relation picked on a plain select, the `:static` mode, stays picked, is saved, and drives the
  pickers that depend on it; the `:load_more` picker does the same through its own events.

  `MishkaGervaz.Test.Resources.PickerStaticEntry` draws `:region_id` and `:workspace_id`, which
  depends on it, as selects. Each case posts what the rendered form holds, as a browser does: every
  hidden input, and every select that is not disabled with the option it shows, with the one picked
  set to its new option. `MishkaGervaz.Test.Resources.PickerLoadMoreEntry` draws the same pair as
  `:load_more` pickers, picked through `relation_select`.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Renderer, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader

  alias MishkaGervaz.Test.Resources.{
    PickerLoadMoreEntry,
    PickerRegion,
    PickerStaticEntry,
    PickerWorkspace
  }

  @user %{id: "user-1", role: :admin}

  setup do
    for resource <- [PickerStaticEntry, PickerLoadMoreEntry, PickerWorkspace, PickerRegion] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    north = Ash.create!(PickerRegion, %{name: "North"})
    south = Ash.create!(PickerRegion, %{name: "South"})
    w1 = Ash.create!(PickerWorkspace, %{name: "W1", region_id: north.id})
    w2 = Ash.create!(PickerWorkspace, %{name: "W2", region_id: north.id})
    w3 = Ash.create!(PickerWorkspace, %{name: "W3", region_id: south.id})

    %{north: north, south: south, w1: w1, w2: w2, w3: w3}
  end

  defp form_id(PickerStaticEntry), do: "picker-static-entry"
  defp form_id(PickerLoadMoreEntry), do: "picker-load-more-entry"

  defp edit_form(resource, entry) do
    state = resource |> form_id() |> State.init(resource, @user) |> State.update(mode: :update)
    {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)

    :load_record
    |> DataLoader.Default.handle_async_result({:ok, {:ok, form}}, build_socket(state))
    |> settle()
  end

  defp create_form(resource, defaults \\ nil) do
    state =
      resource |> form_id() |> State.init(resource, @user) |> State.update(defaults: defaults)

    state |> build_socket() |> DataLoader.new_record(state) |> settle()
  end

  defp settle(socket) do
    for {name, %{loading?: true}} <- socket.assigns.form_state.relation_options,
        reduce: socket,
        do: (acc -> finish_loading(acc, name))
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{
      form_state: socket.assigns.form_state,
      __changed__: %{}
    })
  end

  defp attr(attrs, name) do
    case Regex.run(~r/\s#{name}="([^"]*)"/, attrs, capture: :all_but_first) do
      [value] -> value
      nil -> nil
    end
  end

  defp flag?(attrs, name), do: attrs =~ ~r/\s#{name}(\s|=|$)/

  defp selects(socket) do
    ~r/<select([^>]*)>(.*?)<\/select>/s
    |> Regex.scan(render_form(socket), capture: :all_but_first)
    |> Enum.map(fn [attrs, body] ->
      options =
        ~r/<option([^>]*)>/
        |> Regex.scan(body, capture: :all_but_first)
        |> Enum.map(fn [option] -> {attr(option, "value"), flag?(option, "selected")} end)

      shown =
        case Enum.find(options, fn {_value, selected?} -> selected? end) || List.first(options) do
          {value, _selected?} -> value
          nil -> ""
        end

      %{
        id: attr(attrs, "id"),
        name: attr(attrs, "name"),
        disabled?: flag?(attrs, "disabled"),
        values: Enum.map(options, &elem(&1, 0)),
        shown: shown
      }
    end)
  end

  defp select_of(socket, field) do
    id = socket.assigns.form_state.form[field].id
    Enum.find(selects(socket), &(&1.id == id))
  end

  defp shown(socket, field) do
    case select_of(socket, field) do
      %{shown: shown} -> shown
      nil -> nil
    end
  end

  defp offered(socket, field), do: socket |> select_of(field) |> Map.fetch!(:values)

  defp browser_post(socket, picks, form_params) do
    hidden =
      ~r/<input type="hidden" name="([^"]+)" value="([^"]*)"/
      |> Regex.scan(render_form(socket), capture: :all_but_first)
      |> Enum.reject(fn [name, _value] -> String.starts_with?(name, "form[") end)
      |> Enum.map(fn [name, value] -> {name, value} end)

    picked_ids = Map.new(picks, fn {field, value} -> {select_of(socket, field).id, value} end)

    selected =
      for %{disabled?: false, name: name, id: id, shown: shown} <- selects(socket) do
        {name, Map.get(picked_ids, id, shown)}
      end

    typed = Enum.map(form_params, fn {key, value} -> {"form[#{key}]", value} end)

    (hidden ++ selected ++ typed)
    |> URI.encode_query()
    |> Plug.Conn.Query.decode()
  end

  defp pick(socket, field, value) do
    %{name: name, values: values} = select_of(socket, field)
    assert value in values, "the #{field} select offers no #{inspect(value)}"

    params =
      socket
      |> browser_post([{field, value}], %{})
      |> Map.put("_target", String.split(name, ["[", "]"], trim: true))

    {:noreply, socket} = Events.handle("validate", params, socket)
    socket
  end

  defp validate(socket, form_params) do
    params = socket |> browser_post([], form_params) |> Map.put("_target", ["form", "title"])
    {:noreply, socket} = Events.handle("validate", params, socket)
    socket
  end

  defp save(socket, form_params) do
    {:noreply, socket} = Events.handle("save", browser_post(socket, [], form_params), socket)
    socket
  end

  defp select(socket, field, record) do
    params = %{"filter" => to_string(field), "id" => record.id, "label" => record.name}
    {:noreply, socket} = Events.handle("relation_select", params, socket)
    socket
  end

  defp finish_loading(socket, field_name) do
    state = socket.assigns.form_state
    field = Enum.find(state.static.fields, &(&1.name == field_name))
    result = DataLoader.Default.relation_loader().load_options(field, state)
    DataLoader.Default.handle_async_result({:load_relation, field_name}, {:ok, result}, socket)
  end

  defp form_param(socket, field) do
    socket.assigns.form_state.form.source
    |> AshPhoenix.Form.params()
    |> Map.get(to_string(field))
  end

  defp stored(resource, id) do
    record = Ash.get!(resource, id)
    {record.region_id, record.workspace_id}
  end

  defp saved(mode) do
    assert_received {:form_saved, ^mode, record}
    {record.region_id, record.workspace_id}
  end

  describe "editing an entry on :static selects" do
    setup ctx do
      entry =
        Ash.create!(PickerStaticEntry, %{
          title: "Entry",
          region_id: ctx.north.id,
          workspace_id: ctx.w1.id
        })

      %{entry: entry}
    end

    test "the form opens with the region and the workspace the entry has", ctx do
      socket = edit_form(PickerStaticEntry, ctx.entry)

      assert shown(socket, :region_id) == ctx.north.id
      assert shown(socket, :workspace_id) == ctx.w1.id
    end

    test "a region picked stays selected, and a change to another field keeps it", ctx do
      socket = PickerStaticEntry |> edit_form(ctx.entry) |> pick(:region_id, ctx.south.id)

      assert shown(socket, :region_id) == ctx.south.id
      assert form_param(socket, :region_id) == ctx.south.id

      socket = validate(socket, %{"title" => "Renamed"})

      assert shown(socket, :region_id) == ctx.south.id
      assert form_param(socket, :region_id) == ctx.south.id
    end

    test "a save after picking another region keeps the new one", ctx do
      PickerStaticEntry
      |> edit_form(ctx.entry)
      |> pick(:region_id, ctx.south.id)
      |> validate(%{"title" => "Renamed"})
      |> save(%{"title" => "Renamed"})

      assert saved(:update) == {ctx.south.id, nil}
      assert stored(PickerStaticEntry, ctx.entry.id) == {ctx.south.id, nil}
    end

    test "a workspace picked under the same region is saved", ctx do
      socket =
        PickerStaticEntry
        |> edit_form(ctx.entry)
        |> pick(:workspace_id, ctx.w2.id)
        |> validate(%{"title" => "Renamed"})

      assert shown(socket, :workspace_id) == ctx.w2.id

      save(socket, %{"title" => "Renamed"})

      assert saved(:update) == {ctx.north.id, ctx.w2.id}
    end

    test "the workspace picker reloads for a region picked, and offers only its workspaces",
         ctx do
      socket = PickerStaticEntry |> edit_form(ctx.entry) |> pick(:region_id, ctx.south.id)

      refute Map.has_key?(socket.assigns.form_state.field_values, :workspace_id)
      assert %{loading?: true} = socket.assigns.form_state.relation_options.workspace_id
      assert form_param(socket, :workspace_id) == nil

      socket = finish_loading(socket, :workspace_id)

      assert offered(socket, :workspace_id) -- ["", "__nil__"] == [ctx.w3.id]

      socket |> pick(:workspace_id, ctx.w3.id) |> save(%{"title" => "Moved"})

      assert saved(:update) == {ctx.south.id, ctx.w3.id}
    end

    test "a workspace set back to the empty choice is saved as none", ctx do
      socket = PickerStaticEntry |> edit_form(ctx.entry) |> pick(:workspace_id, "")

      assert shown(socket, :workspace_id) == ""

      socket |> validate(%{"title" => "Renamed"}) |> save(%{"title" => "Renamed"})

      assert saved(:update) == {ctx.north.id, nil}
    end

    test "the No workspace choice is saved as none", ctx do
      socket = PickerStaticEntry |> edit_form(ctx.entry) |> pick(:workspace_id, "__nil__")

      assert shown(socket, :workspace_id) == "__nil__"

      save(socket, %{"title" => "Renamed"})

      assert saved(:update) == {ctx.north.id, nil}
    end

    test "a region set back to the empty choice closes the workspace picker, and saves neither",
         ctx do
      socket = PickerStaticEntry |> edit_form(ctx.entry) |> pick(:region_id, "")

      assert shown(socket, :region_id) == ""
      assert select_of(socket, :workspace_id) == nil
      assert render_form(socket) =~ ~r/Select Region first/i

      save(socket, %{"title" => "Renamed"})

      assert saved(:update) == {nil, nil}
    end
  end

  describe "creating on :static selects" do
    test "a region and a workspace picked on a new entry are saved", ctx do
      socket = PickerStaticEntry |> create_form() |> pick(:region_id, ctx.north.id)

      assert shown(socket, :region_id) == ctx.north.id
      assert %{loading?: true} = socket.assigns.form_state.relation_options.workspace_id

      socket =
        socket
        |> finish_loading(:workspace_id)
        |> pick(:workspace_id, ctx.w2.id)
        |> validate(%{"title" => "New"})

      assert {shown(socket, :region_id), shown(socket, :workspace_id)} ==
               {ctx.north.id, ctx.w2.id}

      save(socket, %{"title" => "New"})

      assert saved(:create) == {ctx.north.id, ctx.w2.id}
    end

    test "the region and workspace given as defaults are shown, and saved", ctx do
      socket = create_form(PickerStaticEntry, %{region_id: ctx.north.id, workspace_id: ctx.w1.id})

      assert {shown(socket, :region_id), shown(socket, :workspace_id)} ==
               {ctx.north.id, ctx.w1.id}

      socket = validate(socket, %{"title" => "New"})

      assert {shown(socket, :region_id), shown(socket, :workspace_id)} ==
               {ctx.north.id, ctx.w1.id}

      save(socket, %{"title" => "New"})

      assert saved(:create) == {ctx.north.id, ctx.w1.id}
    end

    test "a workspace given as a default and set to the empty choice is saved as none", ctx do
      PickerStaticEntry
      |> create_form(%{region_id: ctx.north.id, workspace_id: ctx.w1.id})
      |> pick(:workspace_id, "")
      |> validate(%{"title" => "New"})
      |> save(%{"title" => "New"})

      assert saved(:create) == {ctx.north.id, nil}
    end

    test "another workspace picked over the default is saved", ctx do
      PickerStaticEntry
      |> create_form(%{region_id: ctx.north.id, workspace_id: ctx.w1.id})
      |> pick(:workspace_id, ctx.w2.id)
      |> save(%{"title" => "New"})

      assert saved(:create) == {ctx.north.id, ctx.w2.id}
    end

    test "a region the page gave is drawn disabled, and a region posted for it changes nothing",
         ctx do
      socket = create_form(PickerStaticEntry, %{region_id: ctx.north.id, workspace_id: ctx.w1.id})

      assert select_of(socket, :region_id).disabled?

      forged =
        socket
        |> browser_post([], %{"title" => "New", "region_id" => ctx.south.id})
        |> Map.put("region_id", ctx.south.id)

      {:noreply, socket} =
        Events.handle("validate", Map.put(forged, "_target", ["form", "region_id"]), socket)

      assert socket.assigns.form_state.field_values.region_id == ctx.north.id
      assert socket.assigns.form_state.field_values.workspace_id == ctx.w1.id

      {:noreply, _socket} = Events.handle("save", forged, socket)

      assert saved(:create) == {ctx.north.id, ctx.w1.id}
    end
  end

  describe "a :load_more picker" do
    setup ctx do
      entry =
        Ash.create!(PickerLoadMoreEntry, %{
          title: "Entry",
          region_id: ctx.north.id,
          workspace_id: ctx.w1.id
        })

      %{entry: entry}
    end

    defp held(socket, field) do
      ~r/<input type="hidden" name="#{field}" value="([^"]*)"/
      |> Regex.run(render_form(socket), capture: :all_but_first)
      |> List.wrap()
      |> List.first()
    end

    test "a region picked on an entry stays through a change to another field, and is saved",
         ctx do
      socket =
        PickerLoadMoreEntry
        |> edit_form(ctx.entry)
        |> select(:region_id, ctx.south)
        |> validate(%{"title" => "Renamed"})

      assert held(socket, :region_id) == ctx.south.id
      assert form_param(socket, :region_id) == ctx.south.id

      save(socket, %{"title" => "Renamed"})

      assert saved(:update) == {ctx.south.id, nil}
    end

    test "the workspace picker reloads for the region picked", ctx do
      socket = PickerLoadMoreEntry |> edit_form(ctx.entry) |> select(:region_id, ctx.south)

      refute Map.has_key?(socket.assigns.form_state.field_values, :workspace_id)
      assert %{loading?: true} = socket.assigns.form_state.relation_options.workspace_id

      socket = finish_loading(socket, :workspace_id)

      assert socket.assigns.form_state.relation_options.workspace_id.options ==
               [{"W3", ctx.w3.id}]

      socket
      |> select(:workspace_id, ctx.w3)
      |> validate(%{"title" => "Moved"})
      |> save(%{"title" => "Moved"})

      assert saved(:update) == {ctx.south.id, ctx.w3.id}
    end

    test "the region picked again is cleared, and saved as none", ctx do
      socket =
        PickerLoadMoreEntry
        |> edit_form(ctx.entry)
        |> select(:region_id, ctx.north)
        |> validate(%{"title" => "Renamed"})

      assert held(socket, :region_id) == ""

      save(socket, %{"title" => "Renamed"})

      assert saved(:update) == {nil, nil}
    end

    test "a region and workspace picked on a new entry are saved", ctx do
      PickerLoadMoreEntry
      |> create_form()
      |> select(:region_id, ctx.north)
      |> finish_loading(:workspace_id)
      |> select(:workspace_id, ctx.w2)
      |> validate(%{"title" => "New"})
      |> save(%{"title" => "New"})

      assert saved(:create) == {ctx.north.id, ctx.w2.id}
    end
  end
end

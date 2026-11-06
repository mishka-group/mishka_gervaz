defmodule MishkaGervaz.Form.Web.Events.RelationSearchByChangeTest do
  @moduledoc """
  A relation picker's search box narrows its list from the form's own change, so text that enters
  it without a key press, pasted, filled in or dropped, narrows the list as typed text does, and a
  key press searches once.

  `MishkaGervaz.Test.Resources.PickerCoveredEntry` picks one workspace in the `:search` field
  `:workspace_id` and its regions in the `:search_multi` field `:region_ids`.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Renderer, State}

  alias MishkaGervaz.Test.Resources.{
    PickerCoverage,
    PickerCoveredEntry,
    PickerRegion,
    PickerScopedEntry,
    PickerWorkspace
  }

  @user %{id: "user-1", role: :admin}

  setup do
    for resource <- [PickerCoverage, PickerCoveredEntry, PickerScopedEntry, PickerWorkspace] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    PickerRegion |> Ash.read!() |> Enum.each(&Ash.destroy!/1)

    north = Ash.create!(PickerRegion, %{name: "North"})
    Ash.create!(PickerRegion, %{name: "South"})

    for name <- ["Alpha", "Beta", "Gamma"],
        do: Ash.create!(PickerWorkspace, %{name: name, region_id: north.id})

    state = "picker-covered-entry" |> State.init(PickerCoveredEntry, @user)
    %{socket: DataLoader.new_record(build_socket(state), state)}
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{
      form_state: socket.assigns.form_state,
      __changed__: %{}
    })
  end

  defp event(socket, event, params) do
    {:noreply, socket} = Events.handle(event, params, socket)
    socket
  end

  defp changed(socket, field, text) do
    event(socket, "validate", %{
      "_search_#{field}" => text,
      "_target" => ["_search_#{field}"],
      "form" => %{"title" => ""}
    })
  end

  defp listed(socket, field) do
    socket.assigns.form_state.relation_options
    |> Map.get(field, %{})
    |> Map.get(:options, [])
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  test "text in a :search box narrows its list without a key press", %{socket: socket} do
    socket =
      socket
      |> event("relation_focus", %{"filter" => "workspace_id"})
      |> changed(:workspace_id, "Bet")

    assert listed(socket, :workspace_id) == ["Beta"]
    assert render_form(socket) =~ ~s(phx-value-label="Beta")
    refute render_form(socket) =~ ~s(phx-value-label="Alpha")
  end

  test "text in a :search_multi box narrows its list without a key press", %{socket: socket} do
    socket =
      socket
      |> event("relation_focus", %{"filter" => "region_ids"})
      |> changed(:region_ids, "Sou")

    assert listed(socket, :region_ids) == ["South"]
  end

  test "a change to another field leaves an open list as it is", %{socket: socket} do
    socket = socket |> event("relation_focus", %{"filter" => "workspace_id"})
    before = listed(socket, :workspace_id)

    socket =
      event(socket, "validate", %{
        "_search_workspace_id" => "Bet",
        "_target" => ["form", "title"],
        "form" => %{"title" => "Hello"}
      })

    assert listed(socket, :workspace_id) == before
  end

  test "a key press in the search box sends no search of its own beside the change", %{
    socket: socket
  } do
    html = render_form(socket)

    assert html =~ ~s(name="_search_workspace_id")
    assert html =~ ~s(name="_search_region_ids")
    refute html =~ "relation_search"
  end
end

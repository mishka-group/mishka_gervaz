defmodule MishkaGervaz.Table.Types.Action.LinkRouteTest do
  @moduledoc """
  A `:link` row action named `:edit`, `:show`, `:edit_link` or `:show_link` without a `path`
  builds its address from the table's route, with the route's params filled in from the state.
  Rendered through the plain table and the media card against a real `State`, as a page draws
  them. The `:edit` and `:show` actions that are not links keep their own behaviour.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.MediaGallery
  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Types.Action.Link
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.{InPlaceEdit, LinkRoute}

  @admin %{id: "user-1", role: :admin}
  @record %{id: "rec-1", title: "Lamp"}

  defp table_state(resource, path_params \\ %{}) do
    state =
      "link-route"
      |> State.init(resource, @admin)
      |> State.update(loading: :loaded, has_initial_data?: true)

    %{state | path_params: path_params}
  end

  defp render_table(state) do
    stream_name = state.static.stream_name

    render_component(&TableTemplate.render/1, %{
      static: state.static,
      state: state,
      stream: [{"#{stream_name}-#{@record.id}", @record}],
      streams: %{stream_name => []},
      empty?: false,
      failed?: false,
      myself: nil,
      __changed__: %{}
    })
  end

  defp render_card(state) do
    render_component(&MediaGallery.render_item/1, %{
      id: "card-#{@record.id}",
      record: @record,
      static: state.static,
      state: state,
      show_checkboxes: false,
      myself: nil,
      __changed__: %{}
    })
  end

  defp hrefs(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("a[href]")
    |> LazyHTML.attribute("href")
  end

  describe "a link with no path on the plain table" do
    test "builds the edit and show addresses from the route and its params" do
      hrefs = LinkRoute |> table_state(%{site_id: "site-7"}) |> render_table() |> hrefs()

      assert "/admin/sites/site-7/products/rec-1/edit" in hrefs
      assert "/admin/sites/site-7/products/rec-1" in hrefs
      assert Enum.count(hrefs, &(&1 == "/admin/sites/site-7/products/rec-1/edit")) == 2
      assert Enum.count(hrefs, &(&1 == "/admin/sites/site-7/products/rec-1")) == 2
    end

    test "a path function still decides its own address" do
      hrefs = LinkRoute |> table_state(%{site_id: "site-7"}) |> render_table() |> hrefs()

      assert "/shop/products/rec-1" in hrefs
    end
  end

  describe "a link with no path on the media card" do
    test "builds the same addresses" do
      hrefs = LinkRoute |> table_state(%{site_id: "site-9"}) |> render_card() |> hrefs()

      assert "/admin/sites/site-9/products/rec-1/edit" in hrefs
      assert "/admin/sites/site-9/products/rec-1" in hrefs
      assert "/shop/products/rec-1" in hrefs
    end
  end

  describe "a table with no route" do
    test "links to # instead of a made-up address" do
      action = %{name: :edit, type: :link, ui: %{label: "Edit"}}
      state = table_state(LinkRoute)
      config = put_in(state.static.config, [:identity, :route], nil)
      state = %{state | static: %{state.static | config: config}}

      html =
        %{state: state, static: state.static}
        |> Link.render(action, @record, MishkaGervaz.UIAdapters.Tailwind, nil)
        |> rendered_to_string()

      assert hrefs(html) == ["#"]
    end
  end

  describe "the edit and show actions that are not links" do
    test "an :edit of type :edit runs its js and sends the record to the form" do
      html = InPlaceEdit |> table_state() |> render_table()

      [button] =
        html |> LazyHTML.from_fragment() |> LazyHTML.query("button[title=Edit]") |> Enum.to_list()

      [click] = LazyHTML.attribute(button, "phx-click")

      assert hrefs(html) == []
      assert [["show", %{"to" => "#in-place-form-modal"}], ["push", push]] = Jason.decode!(click)
      assert push["event"] == "row_action"
      assert push["value"] == %{"event" => "edit", "id" => "rec-1"}
    end

    test "a :show of type :event pushes its event" do
      html = InPlaceEdit |> table_state() |> render_table()

      [button] =
        html |> LazyHTML.from_fragment() |> LazyHTML.query("button[title=Show]") |> Enum.to_list()

      assert LazyHTML.attribute(button, "phx-click") == ["custom_event"]
      assert LazyHTML.attribute(button, "phx-value-event") == ["show_details"]
    end
  end
end

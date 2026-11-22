defmodule MishkaGervaz.Table.Web.ArrivedRowLiveTest do
  @moduledoc """
  A row that arrives by a stream insert after the table loaded, over realtime, driven the way a
  reader sees it (`MishkaGervaz.Test.Web.ShelfItem` on `MishkaGervaz.Test.Web.TablePageLive`'s
  `/shelf`).

  It wears a highlight that fades by CSS alone (`starting:` opacity, no JavaScript); the rows the
  table loaded wear none, and neither does a row read again by a fresh load.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Test.Web.ShelfItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @mark ~s|[data-role="gervaz-row-arrived"]|

  setup do
    on_exit(fn -> ShelfItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    %{loaded: Ash.create!(ShelfItem, %{title: "a loaded"})}
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/shelf")
    render_async(view)
    view
  end

  defp notify(view, record) do
    notification = %Ash.Notifier.Notification{
      resource: ShelfItem,
      action: Ash.Resource.Info.action(ShelfItem, :create),
      data: record
    }

    send(view.pid, {:notify, notification})
    render(view)
    render(view)
    render_async(view)
  end

  test "a row that arrives over realtime wears the fading highlight", %{loaded: loaded} do
    view = open()
    refute has_element?(view, "#items #{@mark}")

    arrived = Ash.create!(ShelfItem, %{title: "b arrived"})
    notify(view, arrived)

    assert has_element?(view, ~s|#items [id$="-#{arrived.id}"] #{@mark}[aria-hidden="true"]|)

    assert view |> element(~s|#items [id$="-#{arrived.id}"] #{@mark}|) |> render() =~
             "starting:opacity-100"

    refute has_element?(view, ~s|#items [id$="-#{loaded.id}"] #{@mark}|)
  end

  test "a row read again by a fresh load wears none" do
    view = open()
    arrived = Ash.create!(ShelfItem, %{title: "b arrived"})
    notify(view, arrived)

    view = open()

    refute has_element?(view, "#items #{@mark}")
  end

  test "Shared.arrived/1 marks an Ash record and leaves anything else as it is",
       %{loaded: loaded} do
    assert Shared.arrived?(Shared.arrived(loaded))
    refute Shared.arrived?(loaded)
    assert Shared.arrived(%{id: 1}) == %{id: 1}
    refute Shared.arrived?(%{id: 1})
  end

  test "template_options highlight_arrivals: false draws no highlight", %{loaded: loaded} do
    state =
      "shelf"
      |> MishkaGervaz.Table.Web.State.init(ShelfItem, %{id: "m", site_id: nil, role: :admin})
      |> MishkaGervaz.Table.Web.State.update(loading: :loaded, has_initial_data?: true)

    draw = fn options ->
      static = %{state.static | template_options: options}
      name = static.stream_name

      Phoenix.LiveViewTest.render_component(&MishkaGervaz.Table.Templates.Table.render/1, %{
        static: static,
        state: %{state | static: static},
        stream: [{"#{name}-#{loaded.id}", Shared.arrived(loaded)}],
        streams: %{name => []},
        empty?: false,
        failed?: false,
        myself: nil,
        __changed__: %{}
      })
    end

    assert draw.([]) =~ "gervaz-row-arrived"
    refute draw.(highlight_arrivals: false) =~ "gervaz-row-arrived"
  end
end

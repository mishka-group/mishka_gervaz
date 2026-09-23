defmodule MishkaGervaz.Table.Web.RealtimeTotalTest do
  @moduledoc """
  The table's total — "Showing N", the page count, the empty state — after rows arrive or leave
  over realtime.

  The total is counted again with the table's own read after every notification the table
  handles, and by `DataLoader.refresh_total/1` for a hook that halts and moves rows itself. Counting
  again rather than adding or subtracting one is what these pin: a site admin receives each
  site-scoped notification twice, the tab that deletes a row has already taken it off its total, and
  a row that arrives or changes is counted under the table's filters, not merely because it arrived.
  The same read decides whether that row is shown at all (`DataLoader.in_view?/2`).

  On a connected socket the count is a task, one per burst; these drive both that path and the
  immediate one a disconnected socket — or an empty table — takes.
  """
  # async: false — the ETS resources are shared
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.{DataLoader, Live, State}
  alias MishkaGervaz.Table.Web.DataLoader.PaginationHandler
  alias MishkaGervaz.Test.Resources.PaginationScenarios.Scenario7Resource

  alias MishkaGervaz.Test.DataLoader.{
    ArchivableResource,
    BasicResource,
    FilterableResource,
    HooksResource,
    InfinitePaginationResource,
    MultiTenantResource
  }

  require Ash.Query

  setup do
    on_exit(fn ->
      for resource <- [
            ArchivableResource,
            BasicResource,
            FilterableResource,
            HooksResource,
            InfinitePaginationResource,
            MultiTenantResource,
            Scenario7Resource
          ] do
        try do
          MishkaGervaz.Test.Ets.stop(resource)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end

  defp master_user, do: %{id: "master-1", site_id: nil, role: :admin}
  defp tenant_user(site_id), do: %{id: "tenant-1", site_id: site_id, role: :user}

  defp create!(resource, count, attrs \\ fn i -> %{name: "Item #{i}"} end, opts \\ []) do
    Enum.map(1..count//1, fn i -> Ash.create!(resource, attrs.(i), opts) end)
  end

  defp loaded(resource, user, total, updates \\ []) do
    "table"
    |> State.init(resource, user)
    |> State.update(
      Keyword.merge([loading: :loaded, total_count: total, total_pages: pages(total, 5)], updates)
    )
  end

  defp pages(nil, _size), do: nil
  defp pages(0, _size), do: 1
  defp pages(total, size), do: ceil(total / size)

  defp socket(state) do
    %Phoenix.LiveView.Socket{
      private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
    |> Phoenix.Component.assign(:table_state, state)
    |> Phoenix.Component.assign(:id, state.static.id)
    |> Phoenix.LiveView.stream(state.static.stream_name, [])
  end

  defp connected(socket), do: %{socket | transport_pid: self()}

  defp count_task(socket), do: socket.private[:live_async][:refresh_total]

  defp marker(socket) do
    state = socket.assigns.table_state

    {socket.assigns[:refresh_total_seq] || 0, state.filter_values, state.archive_status,
     state.path_params, state.current_page_size}
  end

  defp refused(query), do: Ash.Query.add_error(query, "the read is refused")

  defp with_hooks(state, hooks),
    do: %{state | static: %{state.static | hooks: Map.merge(state.static.hooks || %{}, hooks)}}

  defp notification(resource, action_name, record) do
    %Ash.Notifier.Notification{
      resource: resource,
      action: Ash.Resource.Info.action(resource, action_name),
      data: record
    }
  end

  defp notify(socket, notification) do
    {:ok, socket} = Live.update(%{pubsub_notification: notification}, socket)
    socket
  end

  defp total(socket), do: socket.assigns.table_state.total_count
  defp total_pages(socket), do: socket.assigns.table_state.total_pages

  defp inserted_ids(socket, state) do
    for {_dom_id, _at, item, _limit, _update_only} <- stream(socket, state).inserts, do: item.id
  end

  defp deleted_dom_ids(socket, state), do: stream(socket, state).deletes

  defp stream(socket, state), do: socket.assigns.streams[state.static.stream_name]

  describe "DataLoader.load_total/1 reads what a load would count" do
    test "a numbered table's count and its pages" do
      create!(BasicResource, 7)

      assert {:ok, %{total_count: 7, total_pages: 2}} =
               DataLoader.load_total(loaded(BasicResource, master_user(), nil))
    end

    test "an empty table is one page of nothing" do
      assert {:ok, %{total_count: 0, total_pages: 1}} =
               DataLoader.load_total(loaded(BasicResource, master_user(), nil))
    end

    test "under the table's filters" do
      create!(FilterableResource, 3, fn i ->
        %{title: "Article #{i}", category: "tech", status: "published"}
      end)

      create!(FilterableResource, 2, fn i ->
        %{title: "Report #{i}", category: "news", status: "draft"}
      end)

      state =
        FilterableResource
        |> loaded(master_user(), nil)
        |> State.update(filter_values: %{search: "Article"})

      assert {:ok, %{total_count: 3}} = DataLoader.load_total(state)
    end

    test "through the table's on_load hook" do
      create!(HooksResource, 4, fn i -> %{name: "On #{i}", active: true} end)
      create!(HooksResource, 3, fn i -> %{name: "Off #{i}", active: false} end)

      state =
        HooksResource
        |> loaded(master_user(), nil)
        |> with_hooks(%{
          on_load: fn query, _state -> {:cont, Ash.Query.filter(query, active)} end
        })

      assert {:ok, %{total_count: 4}} = DataLoader.load_total(state)
    end

    test "for a site admin, their own site's rows only" do
      create!(MultiTenantResource, 2, fn i -> %{name: "Mine #{i}"} end, tenant: "site-a")
      create!(MultiTenantResource, 5, fn i -> %{name: "Theirs #{i}"} end, tenant: "site-b")

      assert {:ok, %{total_count: 2}} =
               DataLoader.load_total(loaded(MultiTenantResource, tenant_user("site-a"), nil))

      assert {:ok, %{total_count: 7}} =
               DataLoader.load_total(loaded(MultiTenantResource, master_user(), nil))
    end

    test "in the archived view, the archived rows" do
      [first, second | _rest] = create!(ArchivableResource, 5)
      Ash.destroy!(first)
      Ash.destroy!(second)

      assert {:ok, %{total_count: 3}} =
               DataLoader.load_total(loaded(ArchivableResource, master_user(), nil))

      assert {:ok, %{total_count: 2}} =
               ArchivableResource
               |> loaded(master_user(), nil, archive_status: :archived)
               |> DataLoader.load_total()
    end

    test "a table without pagination counts every row and has no page count" do
      create!(Scenario7Resource, 12)
      state = loaded(Scenario7Resource, master_user(), nil)

      state = %{
        state
        | static: %{state.static | config: Map.put(state.static.config, :pagination, nil)}
      }

      assert {:ok, %{total_count: 12, total_pages: nil}} = DataLoader.load_total(state)
    end

    test "a load-more or infinite table that shows its total is counted too" do
      create!(InfinitePaginationResource, 4)

      assert {:ok, %{total_count: 4, total_pages: 2}} =
               DataLoader.load_total(loaded(InfinitePaginationResource, master_user(), nil))
    end

    test "a read that reports its own total is counted by reading it" do
      create!(HooksResource, 3)

      state =
        HooksResource
        |> loaded(master_user(), nil)
        |> with_hooks(%{
          on_load: fn query, _state ->
            {:cont, Ash.Query.set_context(query, %{full_count: 42})}
          end
        })

      assert {:ok, %{total_count: 42}} = DataLoader.load_total(state)
    end

    test "a read that narrows itself before it runs is counted by reading it" do
      create!(HooksResource, 4, fn i -> %{name: "On #{i}", active: true} end)
      create!(HooksResource, 3, fn i -> %{name: "Off #{i}", active: false} end)

      narrow = fn query ->
        Ash.Query.before_action(query, &Ash.Query.filter(&1, active))
      end

      state =
        HooksResource
        |> loaded(master_user(), nil)
        |> with_hooks(%{on_load: fn query, _state -> {:cont, narrow.(query)} end})

      assert {:ok, %{total_count: 4}} = DataLoader.load_total(state)
    end

    test "a table without pagination on an action that must paginate is skipped, as its load fails" do
      create!(BasicResource, 3)
      state = loaded(BasicResource, master_user(), nil)

      state = %{
        state
        | static: %{state.static | config: Map.put(state.static.config, :pagination, nil)}
      }

      assert DataLoader.load_total(state) == :skip
    end

    test "a table that keeps no count is skipped" do
      create!(InfinitePaginationResource, 4)

      state =
        InfinitePaginationResource
        |> loaded(master_user(), nil)
        |> then(fn state ->
          ui = %{state.static.pagination_ui | show_total: false}
          %{state | static: %{state.static | pagination_ui: ui}}
        end)

      assert DataLoader.load_total(state) == :skip
    end

    test "a read that returns an error is skipped" do
      state =
        BasicResource
        |> loaded(master_user(), nil)
        |> with_hooks(%{on_load: fn query, _state -> {:cont, refused(query)} end})

      assert DataLoader.load_total(state) == :skip
    end

    test "a hook that raises raises here too, as it does when the table loads" do
      state =
        BasicResource
        |> loaded(master_user(), nil)
        |> with_hooks(%{on_load: fn _query, _state -> raise "the read cannot be built" end})

      assert_raise RuntimeError, "the read cannot be built", fn ->
        DataLoader.load_total(state)
      end
    end

    test "an action the resource does not have raises, as it does in load_page" do
      state = loaded(BasicResource, master_user(), nil)

      assert_raise ArgumentError, ~r/No such read action/, fn ->
        PaginationHandler.Default.load_total(
          state,
          Ash.Query.new(BasicResource),
          :no_such_read,
          nil
        )
      end
    end
  end

  describe "DataLoader.refresh_total/1" do
    test "sets the total and the page count from the data" do
      create!(BasicResource, 7)
      socket = BasicResource |> loaded(master_user(), 3) |> socket() |> DataLoader.refresh_total()

      assert total(socket) == 7
      assert total_pages(socket) == 2
    end

    test "while a load is in flight, leaves the total for the load and reads it once it lands" do
      create!(BasicResource, 7)

      socket =
        BasicResource
        |> loaded(master_user(), 3, loading: :loading)
        |> socket()
        |> DataLoader.refresh_total()

      assert total(socket) == 3
      assert socket.assigns.refresh_total_after_load

      stale_page = {1, %{results: [], more?: false}, true, %{total_count: 3, total_pages: 1}}

      socket =
        socket
        |> Phoenix.Component.assign(:skip_next_url_sync?, true)
        |> then(&DataLoader.handle_async(:load_data, {:ok, stale_page}, &1))

      assert total(socket) == 7
      assert total_pages(socket) == 2
      refute socket.assigns.refresh_total_after_load
    end

    test "a load that fails still leaves the total read once it ends" do
      create!(BasicResource, 7)

      socket =
        BasicResource
        |> loaded(master_user(), 3, loading: :loading)
        |> socket()
        |> DataLoader.refresh_total()
        |> then(&DataLoader.handle_async(:load_data, {:exit, :boom}, &1))

      assert total(socket) == 7
      refute socket.assigns.refresh_total_after_load
    end

    test "a load with nothing asked for leaves the total the load reported" do
      create!(BasicResource, 7)

      socket =
        BasicResource
        |> loaded(master_user(), 3, loading: :loading)
        |> socket()
        |> Phoenix.Component.assign(:skip_next_url_sync?, true)
        |> then(
          &DataLoader.handle_async(
            :load_data,
            {:ok, {1, %{results: [], more?: false}, true, %{total_count: 3, total_pages: 1}}},
            &1
          )
        )

      assert total(socket) == 3
    end

    test "a table with no total yet is left without one" do
      create!(BasicResource, 7)

      socket =
        BasicResource |> loaded(master_user(), nil) |> socket() |> DataLoader.refresh_total()

      assert total(socket) == nil
      refute socket.assigns[:refresh_total_after_load]
    end

    test "a socket with no table is returned as it is" do
      socket = %Phoenix.LiveView.Socket{}
      assert DataLoader.refresh_total(socket) == socket
    end
  end

  describe "DataLoader.refresh_total/1 on a connected socket" do
    test "counts in a task, and a burst while it runs is counted once after it" do
      create!(BasicResource, 7)
      socket = BasicResource |> loaded(master_user(), 3) |> socket() |> connected()

      socket = DataLoader.refresh_total(socket)
      assert {_ref, _pid, :start} = task = count_task(socket)
      assert socket.assigns.refresh_total_running
      assert total(socket) == 3

      socket = socket |> DataLoader.refresh_total() |> DataLoader.refresh_total()
      assert count_task(socket) == task, "a second task was started during the first"
      assert socket.assigns.refresh_total_again
    end

    test "a finished count is applied, and a burst that went on is counted again" do
      create!(BasicResource, 7)

      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> socket()
        |> connected()
        |> Phoenix.Component.assign(:refresh_total_running, true)
        |> Phoenix.Component.assign(:refresh_total_again, true)

      counted = {:ok, %{total_count: 6, total_pages: 2}}
      socket = DataLoader.handle_async(:refresh_total, {:ok, {marker(socket), counted}}, socket)

      assert total(socket) == 6, "a steady burst would never move the total"
      assert socket.assigns.refresh_total_running
      refute socket.assigns.refresh_total_again
      assert count_task(socket), "the rest of the burst was not counted"
    end

    test "a count started before a newer total was set is dropped" do
      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> socket()
        |> Phoenix.Component.assign(:refresh_total_running, true)

      earlier = marker(socket)
      socket = Phoenix.Component.assign(socket, :refresh_total_seq, 1)

      counted = {:ok, %{total_count: 12, total_pages: 3}}
      socket = DataLoader.handle_async(:refresh_total, {:ok, {earlier, counted}}, socket)

      assert total(socket) == 3
    end

    test "a count started before a load landed is dropped" do
      socket =
        BasicResource
        |> loaded(master_user(), 3, loading: :loading)
        |> socket()
        |> Phoenix.Component.assign(:skip_next_url_sync?, true)

      earlier = marker(socket)

      page = {1, %{results: [], more?: false}, true, %{total_count: 5, total_pages: 1}}
      socket = DataLoader.handle_async(:load_data, {:ok, page}, socket)

      counted = {:ok, %{total_count: 12, total_pages: 3}}
      socket = DataLoader.handle_async(:refresh_total, {:ok, {earlier, counted}}, socket)

      assert total(socket) == 5
    end

    test "the last count of a burst is applied" do
      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> socket()
        |> Phoenix.Component.assign(:refresh_total_running, true)

      counted = {:ok, %{total_count: 12, total_pages: 3}}
      socket = DataLoader.handle_async(:refresh_total, {:ok, {marker(socket), counted}}, socket)

      assert total(socket) == 12
      assert total_pages(socket) == 3
      refute socket.assigns.refresh_total_running
    end

    test "a count under filters the table has since left is dropped" do
      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> socket()
        |> Phoenix.Component.assign(:refresh_total_running, true)

      before = marker(socket)

      socket =
        Phoenix.Component.assign(
          socket,
          :table_state,
          State.update(socket.assigns.table_state, filter_values: %{search: "x"})
        )

      counted = {:ok, %{total_count: 12, total_pages: 3}}
      socket = DataLoader.handle_async(:refresh_total, {:ok, {before, counted}}, socket)

      assert total(socket) == 3
    end

    test "a count that lands during a load is left to the load" do
      socket =
        BasicResource
        |> loaded(master_user(), 3, loading: :loading)
        |> socket()
        |> Phoenix.Component.assign(:refresh_total_running, true)

      counted = {:ok, %{total_count: 12, total_pages: 3}}
      socket = DataLoader.handle_async(:refresh_total, {:ok, {marker(socket), counted}}, socket)

      assert total(socket) == 3
    end

    test "a count that fails is followed by the one the burst still owes" do
      create!(BasicResource, 7)

      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> socket()
        |> Phoenix.Component.assign(:refresh_total_running, true)
        |> Phoenix.Component.assign(:refresh_total_again, true)
        |> then(&DataLoader.handle_async(:refresh_total, {:exit, :killed}, &1))

      assert total(socket) == 7
      refute socket.assigns.refresh_total_running
    end

    test "a row going into an empty table is counted at once, so it arrives with its total" do
      [first] = create!(BasicResource, 1)
      state = loaded(BasicResource, master_user(), 0)

      socket =
        state
        |> socket()
        |> connected()
        |> Phoenix.LiveView.stream_insert(state.static.stream_name, first, at: 0)
        |> DataLoader.refresh_total()

      assert total(socket) == 1
      assert count_task(socket) == nil
    end

    test "an empty table with no row going in counts in a task like any other" do
      create!(BasicResource, 1)

      socket =
        BasicResource
        |> loaded(master_user(), 0)
        |> socket()
        |> connected()
        |> DataLoader.refresh_total()

      assert total(socket) == 0
      assert count_task(socket)
    end
  end

  describe "DataLoader.refresh_total/1 and the page a numbered table is on" do
    test "a table left past its last page loads the last page" do
      create!(BasicResource, 10)

      socket =
        BasicResource
        |> loaded(master_user(), 11, page: 3)
        |> socket()
        |> DataLoader.refresh_total()

      assert total(socket) == 10
      assert total_pages(socket) == 2
      assert socket.assigns.table_state.loading == :loading
    end

    test "a table still inside its pages stays where it is" do
      create!(BasicResource, 10)

      socket =
        BasicResource
        |> loaded(master_user(), 11, page: 2)
        |> socket()
        |> DataLoader.refresh_total()

      assert total(socket) == 10
      assert socket.assigns.table_state.loading == :loaded
    end
  end

  describe "DataLoader.in_view?/2 — whether a row belongs in the view" do
    test "under a search, a matching row does and another does not" do
      [article] =
        create!(FilterableResource, 1, fn _ ->
          %{title: "Article", category: "tech", status: "published"}
        end)

      [report] =
        create!(FilterableResource, 1, fn _ ->
          %{title: "Report", category: "news", status: "draft"}
        end)

      state =
        FilterableResource
        |> loaded(master_user(), 1)
        |> State.update(filter_values: %{search: "Article"})

      assert DataLoader.in_view?(state, article.id)
      refute DataLoader.in_view?(state, report.id)
    end

    test "through the table's on_load hook" do
      [on] = create!(HooksResource, 1, fn _ -> %{name: "On", active: true} end)
      [off] = create!(HooksResource, 1, fn _ -> %{name: "Off", active: false} end)

      state =
        HooksResource
        |> loaded(master_user(), 1)
        |> with_hooks(%{
          on_load: fn query, _state -> {:cont, Ash.Query.filter(query, active)} end
        })

      assert DataLoader.in_view?(state, on.id)
      refute DataLoader.in_view?(state, off.id)
    end

    test "under the table's path_params" do
      [first, second] = create!(BasicResource, 2)

      state =
        BasicResource
        |> loaded(master_user(), 1)
        |> Map.put(:path_params, %{name: first.name})

      assert DataLoader.in_view?(state, first.id)
      refute DataLoader.in_view?(state, second.id)
    end

    test "for a site admin, never another site's row" do
      [mine] = create!(MultiTenantResource, 1, fn _ -> %{name: "Mine"} end, tenant: "site-a")
      [theirs] = create!(MultiTenantResource, 1, fn _ -> %{name: "Theirs"} end, tenant: "site-b")

      state = loaded(MultiTenantResource, tenant_user("site-a"), 1)

      assert DataLoader.in_view?(state, mine.id)
      refute DataLoader.in_view?(state, theirs.id)
    end

    test "in the archived view, an archived row does and an active one does not" do
      [archived, active] = create!(ArchivableResource, 2)
      Ash.destroy!(archived)

      state = loaded(ArchivableResource, master_user(), 1, archive_status: :archived)

      assert DataLoader.in_view?(state, archived.id)
      refute DataLoader.in_view?(state, active.id)
    end

    test "a read that returns an error shows the row, as a row arrived before" do
      [row] = create!(BasicResource, 1)

      state =
        BasicResource
        |> loaded(master_user(), 1)
        |> with_hooks(%{on_load: fn query, _state -> {:cont, refused(query)} end})

      assert DataLoader.in_view?(state, row.id)
    end

    test "a hook that raises raises here too, as it does when the table loads" do
      [row] = create!(BasicResource, 1)

      state =
        BasicResource
        |> loaded(master_user(), 1)
        |> with_hooks(%{on_load: fn _query, _state -> raise "the read cannot be built" end})

      assert_raise RuntimeError, "the read cannot be built", fn ->
        DataLoader.in_view?(state, row.id)
      end
    end
  end

  describe "a notification the table handles itself" do
    test "a created row is inserted first, and the total counts it in the same update" do
      create!(BasicResource, 3)
      state = loaded(BasicResource, master_user(), 3)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "New"} end)

      socket = state |> socket() |> notify(notification(BasicResource, :create, record))

      assert total(socket) == 4
      assert inserted_ids(socket, state) == [record.id]
      assert [{_dom_id, 0, _item, _limit, _update_only}] = stream(socket, state).inserts
    end

    test "a destroyed row leaves, and the total with it" do
      [gone | _rest] = create!(BasicResource, 7)
      state = loaded(BasicResource, master_user(), 7)
      Ash.destroy!(gone)

      socket = state |> socket() |> notify(notification(BasicResource, :destroy, gone))

      assert total(socket) == 6
      assert total_pages(socket) == 2
      assert length(deleted_dom_ids(socket, state)) == 1
    end

    test "the same notification twice counts once" do
      create!(BasicResource, 3)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "Twice"} end)
      created = notification(BasicResource, :create, record)

      socket = BasicResource |> loaded(master_user(), 3) |> socket()
      socket = socket |> notify(created) |> notify(created)

      assert total(socket) == 4
    end

    test "the tab that deleted the row does not take it off twice" do
      [gone | _rest] = create!(BasicResource, 7)
      Ash.destroy!(gone)

      socket =
        BasicResource
        |> loaded(master_user(), 6)
        |> socket()
        |> notify(notification(BasicResource, :destroy, gone))

      assert total(socket) == 6
    end

    test "the first row of an empty table leaves the empty state in the same update" do
      state = loaded(BasicResource, master_user(), 0)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "First"} end)

      socket = state |> socket() |> notify(notification(BasicResource, :create, record))

      assert total(socket) == 1
      assert inserted_ids(socket, state) == [record.id]
    end

    test "the last row going shows the empty state" do
      [last] = create!(BasicResource, 1)
      Ash.destroy!(last)

      socket =
        BasicResource
        |> loaded(master_user(), 1)
        |> socket()
        |> notify(notification(BasicResource, :destroy, last))

      assert total(socket) == 0
      assert total_pages(socket) == 1
    end

    test "a row archived away from the active view is taken off the active total" do
      [archived | _rest] = create!(ArchivableResource, 4)
      Ash.destroy!(archived)

      socket =
        ArchivableResource
        |> loaded(master_user(), 4)
        |> socket()
        |> notify(notification(ArchivableResource, :destroy, archived))

      assert total(socket) == 3
    end

    test "under a search, a row that does not match is not counted" do
      create!(FilterableResource, 3, fn i ->
        %{title: "Article #{i}", category: "tech", status: "published"}
      end)

      [report] =
        create!(FilterableResource, 1, fn _ ->
          %{title: "Report", category: "news", status: "draft"}
        end)

      state = loaded(FilterableResource, master_user(), 3, filter_values: %{search: "Article"})
      socket = state |> socket() |> notify(notification(FilterableResource, :create, report))

      assert total(socket) == 3
      assert inserted_ids(socket, state) == [], "a row the search excludes was shown"
    end

    test "under a search, a matching row is shown and counted" do
      create!(FilterableResource, 3, fn i ->
        %{title: "Article #{i}", category: "tech", status: "published"}
      end)

      [matching] =
        create!(FilterableResource, 1, fn _ ->
          %{title: "Article 9", category: "news", status: "draft"}
        end)

      state = loaded(FilterableResource, master_user(), 3, filter_values: %{search: "Article"})
      socket = state |> socket() |> notify(notification(FilterableResource, :create, matching))

      assert total(socket) == 4
      assert inserted_ids(socket, state) == [matching.id]
    end

    test "under a search, a row edited out of it leaves the total" do
      [first | _rest] =
        create!(FilterableResource, 3, fn i ->
          %{title: "Article #{i}", category: "tech", status: "published"}
        end)

      edited = Ash.update!(first, %{title: "Note"})

      state = loaded(FilterableResource, master_user(), 3, filter_values: %{search: "Article"})
      socket = state |> socket() |> notify(notification(FilterableResource, :update, edited))

      assert total(socket) == 2
      assert inserted_ids(socket, state) == []
      assert length(deleted_dom_ids(socket, state)) == 1, "the edited-out row stayed in the list"
    end

    test "an expanded row edited out of the view leaves, and its expansion closes" do
      [first | _rest] =
        create!(FilterableResource, 2, fn i ->
          %{title: "Article #{i}", category: "tech", status: "published"}
        end)

      edited = Ash.update!(first, %{title: "Note"})

      state =
        FilterableResource
        |> loaded(master_user(), 2, filter_values: %{search: "Article"})
        |> State.update(expanded_id: first.id)

      socket = state |> socket() |> notify(notification(FilterableResource, :update, edited))

      assert length(deleted_dom_ids(socket, state)) == 1
      assert socket.assigns.table_state.expanded_id == nil
    end

    test "in the archived view, a row archived elsewhere joins the archived total" do
      [first, second | _rest] = create!(ArchivableResource, 4)
      Ash.destroy!(first)
      state = loaded(ArchivableResource, master_user(), 1, archive_status: :archived)

      archived = Ash.destroy!(second, return_destroyed?: true)
      socket = state |> socket() |> notify(notification(ArchivableResource, :destroy, archived))

      assert total(socket) == 2
      assert inserted_ids(socket, state) == [second.id]
    end

    test "a row another site's admin cannot see changes nothing for them" do
      create!(MultiTenantResource, 2, fn i -> %{name: "Mine #{i}"} end, tenant: "site-a")

      [theirs] =
        create!(MultiTenantResource, 1, fn _ -> %{name: "Theirs"} end, tenant: "site-b")

      state = loaded(MultiTenantResource, tenant_user("site-a"), 99)

      socket = state |> socket() |> notify(notification(MultiTenantResource, :create, theirs))

      assert total(socket) == 99
      assert inserted_ids(socket, state) == []
    end

    test "while a load is in flight, the total waits for it" do
      create!(BasicResource, 3)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "Mid-load"} end)

      socket =
        BasicResource
        |> loaded(master_user(), 3, loading: :loading)
        |> socket()
        |> notify(notification(BasicResource, :create, record))

      assert total(socket) == 3
      assert socket.assigns.refresh_total_after_load
    end

    test "another resource's notification is not this table's" do
      [other] = create!(HooksResource, 1)

      socket =
        BasicResource
        |> loaded(master_user(), 42)
        |> socket()
        |> notify(notification(HooksResource, :create, other))

      assert total(socket) == 42
    end
  end

  describe "an on_realtime hook" do
    test "that continues gets the total the table reads" do
      create!(BasicResource, 3)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "Continued"} end)

      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> with_hooks(%{on_realtime: fn _notification, socket -> {:cont, socket} end})
        |> socket()
        |> notify(notification(BasicResource, :create, record))

      assert total(socket) == 4
    end

    test "that halts leaves the total to the hook" do
      create!(BasicResource, 3)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "Halted"} end)

      socket =
        BasicResource
        |> loaded(master_user(), 3)
        |> with_hooks(%{on_realtime: fn _notification, socket -> {:halt, socket} end})
        |> socket()
        |> notify(notification(BasicResource, :create, record))

      assert total(socket) == 3
    end

    test "that halts and moves rows itself calls refresh_total/1" do
      create!(BasicResource, 3)
      [record] = create!(BasicResource, 1, fn _ -> %{name: "Redrawn"} end)

      hook = fn notification, socket ->
        stream_name = socket.assigns.table_state.static.stream_name

        {:halt,
         socket
         |> Phoenix.LiveView.stream_insert(stream_name, notification.data, at: 0)
         |> DataLoader.refresh_total()}
      end

      state = BasicResource |> loaded(master_user(), 3) |> with_hooks(%{on_realtime: hook})
      socket = state |> socket() |> notify(notification(BasicResource, :create, record))

      assert total(socket) == 4
      assert inserted_ids(socket, state) == [record.id]
    end
  end
end

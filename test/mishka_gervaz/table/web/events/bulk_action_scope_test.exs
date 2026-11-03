defmodule MishkaGervaz.Table.Web.Events.BulkActionScopeTest do
  @moduledoc """
  The rows a select-all bulk action reaches: the ones the table's own read finds, under its
  filters, its search, its `path_params` and its `on_load` hook, less the rows unpicked after
  picking every row. A bulk action never reaches a row the table would not show, such as another
  site's row on a master's table scoped to one site.
  """
  # async: false — the ETS resources are shared
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.Events.BulkActionHandler
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.DataLoader.{FilterableResource, HooksResource, MultiTenantResource}

  require Ash.Query

  @wipe %{name: :wipe, handler: {:type, :destroy}}

  setup do
    on_exit(fn ->
      for resource <- [FilterableResource, HooksResource, MultiTenantResource] do
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

  defp table(resource, updates) do
    "table"
    |> State.init(resource, master_user())
    |> State.update(Keyword.merge([loading: :loaded, select_all?: true], updates))
  end

  defp socket(state),
    do:
      %Phoenix.LiveView.Socket{
        private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
      }
      |> Phoenix.Component.assign(:table_state, state)
      |> Phoenix.LiveView.stream(state.static.stream_name, [])

  defp wipe(state, selected),
    do: BulkActionHandler.Default.execute(@wipe, selected, state, socket(state))

  defp left(resource, field) do
    %{results: rows} = Ash.read!(resource, action: :master_read, page: [limit: 100])
    rows |> Enum.map(&Map.get(&1, field)) |> Enum.sort()
  end

  describe "picking every row" do
    test "reaches only the rows the table's filters find" do
      for {title, category} <- [{"A", "tech"}, {"B", "tech"}, {"C", "news"}],
          do: Ash.create!(FilterableResource, %{title: title, category: category})

      FilterableResource |> table(filter_values: %{category: "tech"}) |> wipe(:all)

      assert left(FilterableResource, :title) == ["C"]
    end

    test "reaches only the rows the table's search finds" do
      for title <- ["Apple pie", "Apple tart", "Banana"],
          do: Ash.create!(FilterableResource, %{title: title})

      FilterableResource |> table(filter_values: %{search: "apple"}) |> wipe(:all)

      assert left(FilterableResource, :title) == ["Banana"]
    end

    test "reaches only the site a master's table is scoped to by its path params" do
      for {name, site} <- [{"a1", "site-a"}, {"a2", "site-a"}, {"b1", "site-b"}],
          do: Ash.create!(MultiTenantResource, %{name: name, site_id: site}, tenant: site)

      MultiTenantResource |> table(path_params: %{site_id: "site-b"}) |> wipe(:all)

      assert left(MultiTenantResource, :name) == ["a1", "a2"]
    end

    test "reaches only the rows the table's on_load hook leaves" do
      for {name, active} <- [{"on", true}, {"off", false}],
          do: Ash.create!(HooksResource, %{name: name, active: active})

      HooksResource
      |> table([])
      |> with_on_load(fn query, _state -> {:cont, Ash.Query.filter(query, active == true)} end)
      |> wipe(:all)

      assert left(HooksResource, :name) == ["off"]
    end

    test "less the rows unpicked after it, under the same filters" do
      [a, _b, _c] =
        for {title, category} <- [{"A", "tech"}, {"B", "tech"}, {"C", "news"}],
            do: Ash.create!(FilterableResource, %{title: title, category: category})

      FilterableResource
      |> table(filter_values: %{category: "tech"})
      |> wipe({:all_except, [a.id]})

      assert left(FilterableResource, :title) == ["A", "C"]
    end
  end

  test "a picked id the table's read does not find, such as another site's row, is left alone" do
    a1 = Ash.create!(MultiTenantResource, %{name: "a1", site_id: "site-a"}, tenant: "site-a")
    b1 = Ash.create!(MultiTenantResource, %{name: "b1", site_id: "site-b"}, tenant: "site-b")

    MultiTenantResource
    |> table(path_params: %{site_id: "site-b"}, select_all?: false)
    |> wipe([a1.id, b1.id])

    assert left(MultiTenantResource, :name) == ["a1"]
  end

  defp with_on_load(state, hook),
    do: %{
      state
      | static: %{state.static | hooks: Map.put(state.static.hooks || %{}, :on_load, hook)}
    }
end

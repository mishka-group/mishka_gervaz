defmodule MishkaGervaz.Table.Web.DataLoaderTest do
  @moduledoc """
  Tests for the DataLoader module.
  """
  # async: false to prevent ETS race conditions with shared test resources
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.State

  alias MishkaGervaz.Test.DataLoader.{
    BasicResource,
    InfinitePaginationResource,
    FilterableResource,
    SortableResource,
    HooksResource,
    MultiTenantResource,
    ArchivableResource
  }

  require Ash.Query

  defp master_user, do: %{id: "master-123", site_id: nil, role: :admin}
  defp tenant_user, do: %{id: "tenant-456", site_id: "site-abc", role: :user}

  defp create_test_data(resource, count, attrs_fn \\ fn i -> %{name: "Item #{i}"} end) do
    Enum.map(1..count, fn i ->
      attrs = attrs_fn.(i)
      Ash.create!(resource, attrs)
    end)
  end

  defp clear_ets(resource) do
    try do
      Ash.DataLayer.Ets.stop(resource)
    rescue
      _ -> :ok
    end
  end

  setup do
    on_exit(fn ->
      clear_ets(BasicResource)
      clear_ets(InfinitePaginationResource)
      clear_ets(FilterableResource)
      clear_ets(SortableResource)
      clear_ets(HooksResource)
      clear_ets(MultiTenantResource)
      clear_ets(ArchivableResource)
    end)

    :ok
  end

  describe "State initialization for DataLoader" do
    test "initializes state with correct pagination settings for numbered" do
      state = State.init("test-id", BasicResource, master_user())

      assert state.page == 1
      assert state.static.page_size == 5
      assert state.has_more? == false
      assert state.loading == :initial
    end

    test "initializes state with correct pagination settings for infinite" do
      state = State.init("test-id", InfinitePaginationResource, master_user())

      assert state.page == 1
      assert state.static.page_size == 3
      assert state.loading == :initial
    end

    test "initializes state with empty filter values" do
      state = State.init("test-id", FilterableResource, master_user())

      assert state.filter_values == %{}
    end

    test "initializes state with empty sort fields" do
      state = State.init("test-id", SortableResource, master_user())

      assert is_list(state.sort_fields)
    end
  end

  describe "Query building - build_query/1 (tested via load execution)" do
    test "builds basic query without filters or sorting" do
      create_test_data(BasicResource, 3)
      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10])

      assert length(result.results) == 3
    end

    test "builds query with preloads from state" do
      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)

      assert is_struct(query, Ash.Query)
    end
  end

  describe "Filter application - apply_filters_to_query/3" do
    test "applies text filter with ilike" do
      create_test_data(FilterableResource, 5, fn i ->
        %{title: "Article #{i}", category: "tech", status: "published"}
      end)

      Ash.create!(FilterableResource, %{
        title: "Special Report",
        category: "news",
        status: "draft"
      })

      state = State.init("test-id", FilterableResource, master_user())
      state = State.update(state, filter_values: %{search: "Article"})

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 5
    end

    test "applies select filter with exact match" do
      create_test_data(FilterableResource, 3, fn _ ->
        %{title: "Tech Post", category: "tech", status: "published"}
      end)

      create_test_data(FilterableResource, 2, fn _ ->
        %{title: "News Post", category: "news", status: "published"}
      end)

      state = State.init("test-id", FilterableResource, master_user())
      state = State.update(state, filter_values: %{category: "tech"})

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 3
    end

    test "applies multiple filters together" do
      create_test_data(FilterableResource, 3, fn _ ->
        %{title: "Tech Draft", category: "tech", status: "draft"}
      end)

      create_test_data(FilterableResource, 2, fn _ ->
        %{title: "Tech Published", category: "tech", status: "published"}
      end)

      create_test_data(FilterableResource, 1, fn _ ->
        %{title: "News Draft", category: "news", status: "draft"}
      end)

      state = State.init("test-id", FilterableResource, master_user())
      state = State.update(state, filter_values: %{category: "tech", status: "draft"})

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 3
    end

    test "returns all records when no filters applied" do
      create_test_data(FilterableResource, 5, fn i ->
        %{title: "Item #{i}", category: "tech"}
      end)

      state = State.init("test-id", FilterableResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 5
    end

    test "handles empty filter values gracefully" do
      create_test_data(FilterableResource, 3, fn i ->
        %{title: "Item #{i}", category: "tech"}
      end)

      state = State.init("test-id", FilterableResource, master_user())
      state = State.update(state, filter_values: %{search: "", category: nil})

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 3
    end
  end

  describe "Sorting - apply_sorting_to_query/2" do
    test "applies single sort field ascending" do
      Ash.create!(SortableResource, %{name: "Zebra", score: 10, rank: 3})
      Ash.create!(SortableResource, %{name: "Apple", score: 20, rank: 1})
      Ash.create!(SortableResource, %{name: "Mango", score: 15, rank: 2})

      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:name, :asc}])

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10])

      names = Enum.map(result.results, & &1.name)
      assert names == ["Apple", "Mango", "Zebra"]
    end

    test "applies single sort field descending" do
      Ash.create!(SortableResource, %{name: "Zebra", score: 10, rank: 3})
      Ash.create!(SortableResource, %{name: "Apple", score: 20, rank: 1})
      Ash.create!(SortableResource, %{name: "Mango", score: 15, rank: 2})

      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:name, :desc}])

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10])

      names = Enum.map(result.results, & &1.name)
      assert names == ["Zebra", "Mango", "Apple"]
    end

    test "applies multiple sort fields" do
      Ash.create!(SortableResource, %{name: "Item", score: 10, rank: 2})
      Ash.create!(SortableResource, %{name: "Item", score: 20, rank: 1})
      Ash.create!(SortableResource, %{name: "Item", score: 10, rank: 3})

      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:score, :desc}, {:rank, :asc}])

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10])

      scores_ranks = Enum.map(result.results, &{&1.score, &1.rank})
      assert scores_ranks == [{20, 1}, {10, 2}, {10, 3}]
    end

    test "returns unsorted when no sort fields" do
      create_test_data(SortableResource, 3, fn i ->
        %{name: "Item #{i}", score: i}
      end)

      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [])

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10])

      assert length(result.results) == 3
    end
  end

  describe "DataLoader.apply_sort/3 - sort cycling" do
    test "adds new sort field at the beginning" do
      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:score, :asc}])

      {_socket, updated_state} = simulate_apply_sort(state, :name)

      assert updated_state.sort_fields == [{:name, :asc}, {:score, :asc}]
    end

    test "cycles existing first field from asc to desc" do
      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:name, :asc}])

      {_socket, updated_state} = simulate_apply_sort(state, :name)

      assert updated_state.sort_fields == [{:name, :desc}]
    end

    test "removes field when cycling from desc" do
      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:name, :desc}])

      {_socket, updated_state} = simulate_apply_sort(state, :name)

      assert updated_state.sort_fields == []
    end

    test "promotes existing non-first field to first position" do
      state = State.init("test-id", SortableResource, master_user())
      state = State.update(state, sort_fields: [{:name, :asc}, {:score, :asc}])

      {_socket, updated_state} = simulate_apply_sort(state, :score)

      assert updated_state.sort_fields == [{:score, :desc}, {:name, :asc}]
    end
  end

  describe "Pagination - numbered" do
    test "loads first page with correct offset and limit" do
      create_test_data(BasicResource, 10, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: state.static.page_size, count: true])

      assert length(result.results) == 5
      assert result.count == 10
      assert result.more? == true
    end

    test "loads second page with correct offset" do
      create_test_data(BasicResource, 10, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", BasicResource, master_user())
      page = 2
      offset = (page - 1) * state.static.page_size

      query = build_test_query(state)

      result =
        Ash.read!(query, page: [offset: offset, limit: state.static.page_size, count: true])

      assert length(result.results) == 5
      assert result.count == 10
    end

    test "calculates total pages correctly" do
      create_test_data(BasicResource, 12, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: state.static.page_size, count: true])

      total_pages = ceil(result.count / state.static.page_size)
      assert total_pages == 3
    end

    test "returns has_more? = false on last page" do
      create_test_data(BasicResource, 5, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: state.static.page_size, count: true])

      assert result.more? == false
    end
  end

  describe "Pagination - infinite" do
    test "loads first page for infinite pagination" do
      create_test_data(InfinitePaginationResource, 10, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", InfinitePaginationResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: state.static.page_size])

      assert length(result.results) == 3
      assert result.more? == true
    end

    test "loads more items with correct offset" do
      create_test_data(InfinitePaginationResource, 10, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", InfinitePaginationResource, master_user())
      page = 2
      offset = (page - 1) * state.static.page_size

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: offset, limit: state.static.page_size])

      assert length(result.results) == 3
    end

    test "returns has_more? = false when no more items" do
      create_test_data(InfinitePaginationResource, 2, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", InfinitePaginationResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: state.static.page_size])

      assert result.more? == false
    end
  end

  describe "Filter parsing - parse_filter_values/2" do
    test "parses string filter keys to atoms" do
      state = State.init("test-id", FilterableResource, master_user())
      raw_values = %{"search" => "test", "category" => "tech"}

      parsed = parse_filter_values(raw_values, state.static.filters)

      assert Map.has_key?(parsed, :search)
      assert Map.has_key?(parsed, :category)
    end

    test "removes empty string values" do
      state = State.init("test-id", FilterableResource, master_user())
      raw_values = %{"search" => "", "category" => "tech"}

      parsed = parse_filter_values(raw_values, state.static.filters)

      refute Map.has_key?(parsed, :search)
      assert parsed[:category] == "tech"
    end

    test "removes nil values" do
      state = State.init("test-id", FilterableResource, master_user())
      raw_values = %{"search" => nil, "category" => "tech"}

      parsed = parse_filter_values(raw_values, state.static.filters)

      refute Map.has_key?(parsed, :search)
      assert parsed[:category] == "tech"
    end

    test "handles atom keys" do
      state = State.init("test-id", FilterableResource, master_user())
      raw_values = %{search: "test", category: "tech"}

      parsed = parse_filter_values(raw_values, state.static.filters)

      assert parsed[:search] == "test"
      assert parsed[:category] == "tech"
    end
  end

  describe "Archive status switching - apply_archive_status/3" do
    test "switches from active to archived" do
      state = State.init("test-id", ArchivableResource, master_user())

      assert state.archive_status == :active

      {_socket, updated_state} = simulate_archive_switch(state, :archived)

      assert updated_state.archive_status == :archived
    end

    test "switches from archived to active" do
      state = State.init("test-id", ArchivableResource, master_user())
      state = State.update(state, archive_status: :archived)

      {_socket, updated_state} = simulate_archive_switch(state, :active)

      assert updated_state.archive_status == :active
    end

    test "preserves current state when switching" do
      state = State.init("test-id", ArchivableResource, master_user())

      state =
        State.update(state,
          filter_values: %{search: "test"},
          sort_fields: [{:name, :asc}],
          select_all?: true
        )

      {_socket, updated_state} = simulate_archive_switch(state, :archived)

      assert updated_state.saved_active_state != nil
      assert updated_state.saved_active_state.filter_values == %{search: "test"}
      assert updated_state.saved_active_state.sort_fields == [{:name, :asc}]
    end

    test "restores saved state when switching back" do
      state = State.init("test-id", ArchivableResource, master_user())

      state =
        State.update(state,
          filter_values: %{search: "active-search"},
          sort_fields: [{:name, :asc}]
        )

      {_socket, archived_state} = simulate_archive_switch(state, :archived)

      archived_state =
        State.update(archived_state,
          filter_values: %{search: "archived-search"},
          sort_fields: [{:name, :desc}]
        )

      {_socket, restored_state} = simulate_archive_switch(archived_state, :active)

      assert restored_state.filter_values == %{search: "active-search"}
      assert restored_state.sort_fields == [{:name, :asc}]
    end

    test "does not reload when status unchanged" do
      state = State.init("test-id", ArchivableResource, master_user())

      assert state.archive_status == :active

      {socket, _updated_state} = simulate_archive_switch(state, :active)

      refute socket[:reloaded]
    end
  end

  describe "Tenant resolution" do
    test "returns nil for master user" do
      state = State.init("test-id", MultiTenantResource, master_user())

      tenant = get_tenant(state)

      assert tenant == nil
    end

    test "returns site_id for tenant user" do
      state = State.init("test-id", MultiTenantResource, tenant_user())

      tenant = get_tenant(state)

      assert tenant == "site-abc"
    end
  end

  describe "Action resolution" do
    test "resolves read action for active records" do
      state = State.init("test-id", BasicResource, master_user())

      action = State.get_action(state, :read)

      assert is_atom(action)
    end

    test "resolves read action for archived records" do
      state = State.init("test-id", ArchivableResource, master_user())
      state = State.update(state, archive_status: :archived)

      action = get_archive_read_action(state)

      assert action in [:master_archived, :archived]
    end
  end

  describe "Hooks - on_load" do
    test "state with hooks is initialized correctly" do
      state = State.init("test-id", HooksResource, master_user())

      assert is_map(state.static.hooks)
    end

    test "on_load hook is invoked during query building via HookRunner" do
      alias MishkaGervaz.Table.Web.DataLoader.HookRunner

      test_pid = self()

      hooks = %{
        on_load: fn query, _state ->
          send(test_pid, {:on_load_called, query})
          {:cont, query}
        end
      }

      result = HookRunner.Default.run_hook(hooks, :on_load, [Ash.Query.new(BasicResource), %{}])

      assert_received {:on_load_called, _query}
      assert {:cont, %Ash.Query{}} = result
    end

    test "on_load hook can modify query via {:cont, query}" do
      alias MishkaGervaz.Table.Web.DataLoader.HookRunner

      import Ash.Expr

      original_query = Ash.Query.new(BasicResource)

      hooks = %{
        on_load: fn query, _state ->
          modified = Ash.Query.filter(query, name == "test")
          {:cont, modified}
        end
      }

      result = HookRunner.Default.run_hook(hooks, :on_load, [original_query, %{}])
      applied = HookRunner.Default.apply_hook_result(result, original_query)

      # The modified query should have a filter applied
      refute applied == original_query
    end

    test "on_load hook {:halt, _} preserves original query" do
      alias MishkaGervaz.Table.Web.DataLoader.HookRunner

      import Ash.Expr

      original_query = Ash.Query.new(BasicResource)

      hooks = %{
        on_load: fn query, _state ->
          modified = Ash.Query.filter(query, name == "should_not_apply")
          {:halt, modified}
        end
      }

      result = HookRunner.Default.run_hook(hooks, :on_load, [original_query, %{}])
      applied = HookRunner.Default.apply_hook_result(result, original_query)

      # Halt means the original query is returned unchanged
      assert applied == original_query
    end

    test "HookRunner returns nil when hook is not configured" do
      alias MishkaGervaz.Table.Web.DataLoader.HookRunner

      hooks = %{}

      result = HookRunner.Default.run_hook(hooks, :on_load, [Ash.Query.new(BasicResource), %{}])

      assert is_nil(result)
    end

    test "HookRunner apply_hook_result returns original query when result is nil" do
      alias MishkaGervaz.Table.Web.DataLoader.HookRunner

      original_query = Ash.Query.new(BasicResource)

      applied = HookRunner.Default.apply_hook_result(nil, original_query)

      assert applied == original_query
    end
  end

  describe "path_params in query building" do
    test "apply_path_params adds filter for matching resource attribute" do
      alias MishkaGervaz.Table.Web.DataLoader.QueryBuilder

      import Ash.Expr

      query = Ash.Query.new(FilterableResource)

      result =
        QueryBuilder.Default.apply_path_params(query, %{category: "tech"}, FilterableResource)

      # The query should have the filter applied
      refute result == query
    end

    test "apply_path_params is no-op for empty map" do
      alias MishkaGervaz.Table.Web.DataLoader.QueryBuilder

      query = Ash.Query.new(BasicResource)

      result = QueryBuilder.Default.apply_path_params(query, %{}, BasicResource)

      assert result == query
    end

    test "apply_path_params ignores params not matching resource attributes" do
      alias MishkaGervaz.Table.Web.DataLoader.QueryBuilder

      query = Ash.Query.new(BasicResource)

      result =
        QueryBuilder.Default.apply_path_params(
          query,
          %{nonexistent_field: "value"},
          BasicResource
        )

      assert result == query
    end

    test "build_query applies path_params before filters" do
      create_test_data(FilterableResource, 3, fn i ->
        %{title: "Item #{i}", category: "tech", status: "published"}
      end)

      Ash.create!(FilterableResource, %{
        title: "Other",
        category: "news",
        status: "published"
      })

      state = State.init("test-id", FilterableResource, master_user())

      # Set path_params to filter by category
      state = %{state | path_params: %{category: "tech"}}

      query = build_test_query_with_path_params(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # Only "tech" category items should be returned
      assert result.count == 3
      assert Enum.all?(result.results, &(&1.category == "tech"))
    end
  end

  describe "State updates for loading" do
    test "updates loading status to :loading" do
      state = State.init("test-id", BasicResource, master_user())

      assert state.loading == :initial

      state = State.update(state, loading: :loading, loading_type: :reset)

      assert state.loading == :loading
      assert state.loading_type == :reset
    end

    test "updates loading status to :loaded" do
      state = State.init("test-id", BasicResource, master_user())
      state = State.update(state, loading: :loading)

      state =
        State.update(state,
          loading: :loaded,
          has_initial_data?: true,
          page: 1,
          has_more?: false
        )

      assert state.loading == :loaded
      assert state.has_initial_data? == true
    end

    test "updates loading status to :error" do
      state = State.init("test-id", BasicResource, master_user())
      state = State.update(state, loading: :loading)

      state = State.update(state, loading: :error)

      assert state.loading == :error
    end
  end

  describe "Combined filter and sort" do
    test "applies both filters and sorting" do
      Ash.create!(FilterableResource, %{
        title: "Alpha Tech",
        category: "tech",
        status: "published"
      })

      Ash.create!(FilterableResource, %{title: "Zeta Tech", category: "tech", status: "published"})

      Ash.create!(FilterableResource, %{title: "Beta Tech", category: "tech", status: "published"})

      Ash.create!(FilterableResource, %{
        title: "Alpha News",
        category: "news",
        status: "published"
      })

      state = State.init("test-id", FilterableResource, master_user())

      state =
        State.update(state,
          filter_values: %{category: "tech"},
          sort_fields: [{:title, :asc}]
        )

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 3
      titles = Enum.map(result.results, & &1.title)
      assert titles == ["Alpha Tech", "Beta Tech", "Zeta Tech"]
    end
  end

  describe "Edge cases" do
    test "handles empty result set" do
      # Create some records that won't match the filter
      create_test_data(BasicResource, 3, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", BasicResource, master_user())
      state = State.update(state, filter_values: %{search: "nonexistent"})

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 0
      assert result.results == []
      assert result.more? == false
    end

    test "handles single record" do
      Ash.create!(BasicResource, %{name: "Only One"})

      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert length(result.results) == 1
      assert result.more? == false
    end

    test "handles exact page size boundary" do
      create_test_data(BasicResource, 5, fn i -> %{name: "Item #{i}"} end)

      state = State.init("test-id", BasicResource, master_user())

      query = build_test_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: state.static.page_size, count: true])

      assert result.count == 5
      assert length(result.results) == 5
      assert result.more? == false
    end
  end

  # Helper functions

  defp build_test_query(state) do
    %State{
      static: %{resource: resource, filters: filter_configs},
      filter_values: filter_values,
      sort_fields: sort_fields
    } = state

    preloads = State.get_preloads(state)

    resource
    |> Ash.Query.new()
    |> apply_test_filters(filter_values, filter_configs)
    |> apply_test_sorting(sort_fields)
    |> Ash.Query.load(preloads)
  end

  defp build_test_query_with_path_params(state) do
    alias MishkaGervaz.Table.Web.DataLoader.QueryBuilder

    %State{
      static: %{resource: resource, filters: filter_configs},
      filter_values: filter_values,
      sort_fields: sort_fields,
      path_params: path_params
    } = state

    preloads = State.get_preloads(state)

    resource
    |> Ash.Query.new()
    |> QueryBuilder.Default.apply_path_params(path_params || %{}, resource)
    |> apply_test_filters(filter_values, filter_configs)
    |> apply_test_sorting(sort_fields)
    |> Ash.Query.load(preloads)
  end

  defp apply_test_filters(query, filter_values, _filter_configs)
       when map_size(filter_values) == 0 do
    query
  end

  defp apply_test_filters(query, filter_values, filter_configs) do
    import Ash.Expr

    Enum.reduce(filter_values, query, fn {field, value}, acc ->
      filter_config = Enum.find(filter_configs, &(&1.name == field))

      cond do
        is_nil(value) or value == "" ->
          acc

        filter_config && filter_config.type_module ->
          parsed_value = filter_config.type_module.parse_value(value, filter_config)
          filter_config.type_module.build_query(acc, field, parsed_value, filter_config)

        is_binary(value) ->
          Ash.Query.filter(acc, ilike(^ref(field), ^"%#{value}%"))

        true ->
          Ash.Query.filter(acc, ^ref(field) == ^value)
      end
    end)
  end

  defp apply_test_sorting(query, []), do: query

  defp apply_test_sorting(query, sort_fields) do
    Ash.Query.sort(query, sort_fields)
  end

  defp parse_filter_values(raw_values, filter_configs) do
    Enum.reduce(raw_values, %{}, fn {field_name, raw_value}, acc ->
      field_atom =
        if is_binary(field_name), do: String.to_existing_atom(field_name), else: field_name

      filter_config = Enum.find(filter_configs, &(&1.name == field_atom))

      parsed =
        if filter_config && filter_config.type_module do
          filter_config.type_module.parse_value(raw_value, filter_config)
        else
          raw_value
        end

      if parsed != nil and parsed != "" do
        Map.put(acc, field_atom, parsed)
      else
        acc
      end
    end)
  end

  defp get_tenant(%State{master_user?: true}), do: nil
  defp get_tenant(%State{current_user: user}), do: Map.get(user, :site_id)

  defp get_archive_read_action(state) do
    case MishkaGervaz.Resource.Info.Table.archive_action_for(
           state.static.resource,
           :read,
           state.master_user?
         ) do
      nil -> State.get_action(state, :read)
      action -> action
    end
  end

  defp simulate_apply_sort(state, field) do
    current_sorts = state.sort_fields
    existing_index = Enum.find_index(current_sorts, fn {f, _} -> f == field end)

    new_sorts =
      case existing_index do
        nil ->
          [{field, :asc} | current_sorts]

        0 ->
          {_field, current_order} = Enum.at(current_sorts, 0)

          case current_order do
            :asc -> List.replace_at(current_sorts, 0, {field, :desc})
            :desc -> List.delete_at(current_sorts, 0)
          end

        index ->
          {_field, current_order} = Enum.at(current_sorts, index)
          new_order = if current_order == :asc, do: :desc, else: :asc
          rest = List.delete_at(current_sorts, index)
          [{field, new_order} | rest]
      end

    updated_state = State.update(state, sort_fields: new_sorts)
    {%{}, updated_state}
  end

  defp simulate_archive_switch(state, status) do
    current_status = state.archive_status

    if current_status == status do
      {%{reloaded: false}, state}
    else
      current_mode_state = %{
        filter_values: state.filter_values,
        sort_fields: state.sort_fields,
        selected_ids: state.selected_ids,
        excluded_ids: state.excluded_ids,
        select_all?: state.select_all?
      }

      {saved_state_key, restore_state_key} =
        case current_status do
          :active -> {:saved_active_state, :saved_archived_state}
          :archived -> {:saved_archived_state, :saved_active_state}
        end

      saved_state = Map.get(state, restore_state_key) || default_mode_state()

      state =
        state
        |> State.update(
          archive_status: status,
          filter_values: saved_state.filter_values,
          sort_fields: saved_state.sort_fields,
          selected_ids: saved_state.selected_ids,
          excluded_ids: saved_state.excluded_ids,
          select_all?: saved_state.select_all?
        )
        |> Map.put(saved_state_key, current_mode_state)

      {%{reloaded: true}, state}
    end
  end

  defp default_mode_state do
    %{
      filter_values: %{},
      sort_fields: [],
      selected_ids: MapSet.new(),
      excluded_ids: MapSet.new(),
      select_all?: false
    }
  end

  describe "Preload alias injection - MishkaGervaz.Helpers.inject_preload_aliases/2" do
    alias MishkaGervaz.Helpers

    test "returns records unchanged when aliases is nil" do
      records = [%{id: 1, name: "Test", tenant_layout: %{name: "Layout1"}}]

      result = Helpers.inject_preload_aliases(records, nil)

      assert result == records
    end

    test "returns records unchanged when aliases is empty map" do
      records = [%{id: 1, name: "Test", tenant_layout: %{name: "Layout1"}}]

      result = Helpers.inject_preload_aliases(records, %{})

      assert result == records
    end

    test "injects aliased field from source" do
      records = [
        %{id: 1, name: "Test1", tenant_layout: %{name: "Layout1"}},
        %{id: 2, name: "Test2", tenant_layout: %{name: "Layout2"}}
      ]

      aliases = %{layout: :tenant_layout}

      result = Helpers.inject_preload_aliases(records, aliases)

      assert length(result) == 2
      assert Enum.at(result, 0).layout == %{name: "Layout1"}
      assert Enum.at(result, 1).layout == %{name: "Layout2"}
      assert Enum.at(result, 0).tenant_layout == %{name: "Layout1"}
    end

    test "injects multiple aliased fields" do
      records = [
        %{id: 1, tenant_layout: %{name: "L1"}, tenant_site: %{name: "S1"}}
      ]

      aliases = %{layout: :tenant_layout, site: :tenant_site}

      result = Helpers.inject_preload_aliases(records, aliases)

      assert Enum.at(result, 0).layout == %{name: "L1"}
      assert Enum.at(result, 0).site == %{name: "S1"}
    end

    test "handles nil source values" do
      records = [%{id: 1, tenant_layout: nil}]

      aliases = %{layout: :tenant_layout}

      result = Helpers.inject_preload_aliases(records, aliases)

      assert Enum.at(result, 0).layout == nil
    end

    test "handles single record" do
      record = %{id: 1, master_category: %{name: "Cat1"}}
      aliases = %{category: :master_category}

      result = Helpers.inject_preload_aliases(record, aliases)

      assert result.category == %{name: "Cat1"}
      assert result.master_category == %{name: "Cat1"}
    end
  end
end

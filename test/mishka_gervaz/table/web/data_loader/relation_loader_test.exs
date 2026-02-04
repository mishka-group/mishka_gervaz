defmodule MishkaGervaz.Table.Web.DataLoader.RelationLoaderTest do
  @moduledoc """
  Tests for RelationLoader module.

  Tests different pagination scenarios:
  1. Resource WITHOUT pagination - returns plain list
  2. Resource WITH optional pagination (required?: false) - can use page: false
  3. Resource WITH required pagination (required?: true) - MUST paginate
  4. Tenant support for master and tenant users
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.DataLoader.RelationLoader.Default, as: RelationLoader

  alias MishkaGervaz.Test.RelationLoader.{
    NoPaginationResource,
    OptionalPaginationResource,
    RequiredPaginationResource,
    MultiTenantRelationResource,
    ParentResource
  }

  defp master_user, do: %{id: "master-123", site_id: nil, role: :admin}
  defp tenant_user, do: %{id: "tenant-456", site_id: "site-abc", role: :user}

  defp create_records(resource, count, attrs_fn \\ fn i -> %{name: "Item #{i}"} end) do
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
      clear_ets(NoPaginationResource)
      clear_ets(OptionalPaginationResource)
      clear_ets(RequiredPaginationResource)
      clear_ets(MultiTenantRelationResource)
      clear_ets(ParentResource)
    end)

    :ok
  end

  defp build_filter(resource, opts \\ []) do
    %{
      name: Keyword.get(opts, :name, :test_filter),
      type: :relation,
      mode: Keyword.get(opts, :mode, :load_more),
      resource: resource,
      display_field: Keyword.get(opts, :display_field, :name),
      load_action: Keyword.get(opts, :load_action, :read),
      page_size: Keyword.get(opts, :page_size, 20),
      include_nil: Keyword.get(opts, :include_nil, false)
    }
  end

  defp build_mock_state(user) do
    %{
      current_user: user,
      master_user?: user.site_id == nil,
      static: %{resource: ParentResource}
    }
  end

  # ============================================================================
  # Ash.read return types - understanding pagination behavior
  # ============================================================================

  describe "Ash.read return types - understanding pagination behavior" do
    test "resource WITHOUT pagination returns plain list" do
      create_records(NoPaginationResource, 5)

      result = Ash.read!(NoPaginationResource)

      assert is_list(result)
      assert length(result) == 5
      refute is_struct(result)
    end

    test "resource WITH optional pagination returns Page struct by default" do
      create_records(OptionalPaginationResource, 5)

      result = Ash.read!(OptionalPaginationResource, page: [offset: 0, limit: 10])

      assert is_struct(result, Ash.Page.Offset)
      assert is_list(result.results)
      assert length(result.results) == 5
    end

    test "resource WITH optional pagination can use page: false to get plain list" do
      create_records(OptionalPaginationResource, 5)

      result = Ash.read!(OptionalPaginationResource, page: false)

      assert is_list(result)
      assert length(result) == 5
      refute is_struct(result, Ash.Page.Offset)
    end

    test "resource WITH required pagination CANNOT use page: false" do
      create_records(RequiredPaginationResource, 5)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(RequiredPaginationResource, page: false)
      end
    end

    test "resource WITH required pagination MUST provide page options" do
      create_records(RequiredPaginationResource, 5)

      result = Ash.read!(RequiredPaginationResource, page: [offset: 0, limit: 10])

      assert is_struct(result, Ash.Page.Offset)
      assert length(result.results) == 5
    end
  end

  # ============================================================================
  # RelationLoader.load_options/3 - static mode (page: false)
  # ============================================================================

  describe "RelationLoader.load_options/3 - static mode (page: false)" do
    test "works with resource WITHOUT pagination - loads all 35 items" do
      create_records(NoPaginationResource, 35)

      filter = build_filter(NoPaginationResource, mode: :static)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state)

      assert is_list(result.options)
      assert length(result.options) == 35
      assert result.has_more? == false
      assert result.total_count == 35
    end

    test "works with resource WITH optional pagination - loads all 35 items using page: false" do
      create_records(OptionalPaginationResource, 35)

      filter = build_filter(OptionalPaginationResource, mode: :static)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state)

      assert is_list(result.options)
      assert length(result.options) == 35
      assert result.has_more? == false
      assert result.total_count == 35
    end

    test "returns error for resource WITH required pagination" do
      create_records(RequiredPaginationResource, 35)

      filter = build_filter(RequiredPaginationResource, mode: :static)
      state = build_mock_state(master_user())

      result = RelationLoader.load_options(filter, state)

      assert {:error, %Ash.Error.Invalid{}} = result
    end
  end

  # ============================================================================
  # RelationLoader.load_options/3 - load_more mode (paginated)
  # ============================================================================

  describe "RelationLoader.load_options/3 - load_more mode (paginated)" do
    test "returns paginated results with has_more? flag - 35 items" do
      create_records(OptionalPaginationResource, 35)

      filter = build_filter(OptionalPaginationResource, mode: :load_more, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state, page: 1)

      assert is_list(result.options)
      assert length(result.options) == 10
      assert result.has_more? == true
      assert result.page == 1
    end

    test "loads all 4 pages correctly for 35 items" do
      create_records(OptionalPaginationResource, 35)

      filter = build_filter(OptionalPaginationResource, mode: :load_more, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, page1} = RelationLoader.load_options(filter, state, page: 1)
      {:ok, page2} = RelationLoader.load_options(filter, state, page: 2)
      {:ok, page3} = RelationLoader.load_options(filter, state, page: 3)
      {:ok, page4} = RelationLoader.load_options(filter, state, page: 4)

      assert length(page1.options) == 10
      assert page1.has_more? == true

      assert length(page2.options) == 10
      assert page2.has_more? == true

      assert length(page3.options) == 10
      assert page3.has_more? == true

      assert length(page4.options) == 5
      assert page4.has_more? == false

      # Total should be 35
      total =
        length(page1.options) + length(page2.options) + length(page3.options) +
          length(page4.options)

      assert total == 35
    end
  end

  # ============================================================================
  # RelationLoader.search_options/4 - search mode
  # ============================================================================

  describe "RelationLoader.search_options/4 - search mode" do
    test "filters results by search term - 25 Alpha out of 40 total" do
      create_records(OptionalPaginationResource, 25, fn i -> %{name: "Alpha #{i}"} end)
      create_records(OptionalPaginationResource, 15, fn i -> %{name: "Beta #{i}"} end)

      filter = build_filter(OptionalPaginationResource, mode: :search, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.search_options(filter, state, "Alpha")

      assert is_list(result.options)
      assert length(result.options) == 10
      assert result.has_more? == true
      assert Enum.all?(result.options, fn {label, _id} -> String.contains?(label, "Alpha") end)
    end

    test "search pagination works across pages - 25 matching items" do
      create_records(OptionalPaginationResource, 25, fn i -> %{name: "Alpha #{i}"} end)
      create_records(OptionalPaginationResource, 15, fn i -> %{name: "Beta #{i}"} end)

      filter = build_filter(OptionalPaginationResource, mode: :search, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, page1} = RelationLoader.search_options(filter, state, "Alpha", page: 1)
      {:ok, page2} = RelationLoader.search_options(filter, state, "Alpha", page: 2)
      {:ok, page3} = RelationLoader.search_options(filter, state, "Alpha", page: 3)

      assert length(page1.options) == 10
      assert page1.has_more? == true

      assert length(page2.options) == 10
      assert page2.has_more? == true

      assert length(page3.options) == 5
      assert page3.has_more? == false

      # All should be Alpha items
      all_options = page1.options ++ page2.options ++ page3.options
      assert length(all_options) == 25
      assert Enum.all?(all_options, fn {label, _id} -> String.contains?(label, "Alpha") end)
    end

    test "returns empty when no match in 30 items" do
      create_records(OptionalPaginationResource, 30, fn i -> %{name: "Item #{i}"} end)

      filter = build_filter(OptionalPaginationResource, mode: :search, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.search_options(filter, state, "nonexistent")

      assert result.options == []
      assert result.has_more? == false
    end
  end

  # ============================================================================
  # RelationLoader.resolve_selected/3 - resolving selected IDs
  # ============================================================================

  describe "RelationLoader.resolve_selected/3 - resolving selected IDs" do
    test "resolves 10 selected IDs from 30 records" do
      records = create_records(OptionalPaginationResource, 30)
      selected_ids = records |> Enum.take(10) |> Enum.map(&to_string(&1.id))

      filter = build_filter(OptionalPaginationResource)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.resolve_selected(filter, state, selected_ids)

      assert is_list(result)
      assert length(result) == 10
    end

    test "handles empty selected IDs" do
      filter = build_filter(OptionalPaginationResource)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.resolve_selected(filter, state, [])

      assert result == []
    end

    test "handles nil selected IDs" do
      filter = build_filter(OptionalPaginationResource)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.resolve_selected(filter, state, nil)

      assert result == []
    end

    test "handles __nil__ special value mixed with real IDs" do
      records = create_records(OptionalPaginationResource, 30)
      selected_ids = ["__nil__"] ++ (records |> Enum.take(5) |> Enum.map(&to_string(&1.id)))

      filter = build_filter(OptionalPaginationResource, include_nil: "None")
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.resolve_selected(filter, state, selected_ids)

      assert length(result) == 6
      assert hd(result) == {"None", "__nil__"}
    end
  end

  # ============================================================================
  # Tenant support - master vs tenant user
  # ============================================================================

  describe "Tenant support - master vs tenant user" do
    test "master user gets nil tenant" do
      state = build_mock_state(master_user())
      tenant = get_tenant_from_state(state)

      assert tenant == nil
    end

    test "tenant user gets site_id as tenant" do
      state = build_mock_state(tenant_user())
      tenant = get_tenant_from_state(state)

      assert tenant == "site-abc"
    end

    test "load_options works for master user on multi-tenant resource" do
      Ash.create!(MultiTenantRelationResource, %{name: "Global Item 1"})
      Ash.create!(MultiTenantRelationResource, %{name: "Global Item 2", site_id: "site-abc"})

      filter = build_filter(MultiTenantRelationResource, mode: :load_more, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state)

      # Master should see both records (global access)
      assert length(result.options) >= 1
    end

    test "load_options works for tenant user on multi-tenant resource" do
      Ash.create!(MultiTenantRelationResource, %{name: "Tenant Item 1", site_id: "site-abc"})
      Ash.create!(MultiTenantRelationResource, %{name: "Other Tenant Item", site_id: "site-xyz"})

      filter = build_filter(MultiTenantRelationResource, mode: :load_more, page_size: 10)
      state = build_mock_state(tenant_user())

      {:ok, result} = RelationLoader.load_options(filter, state)

      # With tenant passed, should only see tenant's data
      assert length(result.options) == 1
      assert hd(result.options) |> elem(0) == "Tenant Item 1"
    end
  end

  # ============================================================================
  # Edge cases and error handling
  # ============================================================================

  describe "Edge cases and error handling" do
    test "handles empty database" do
      filter = build_filter(OptionalPaginationResource, mode: :load_more)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state)

      assert result.options == []
      assert result.has_more? == false
    end

    test "handles single record" do
      create_records(OptionalPaginationResource, 1)

      filter = build_filter(OptionalPaginationResource, mode: :load_more, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state)

      assert length(result.options) == 1
      assert result.has_more? == false
    end

    test "handles exact page size boundary - 30 items with page_size 10" do
      create_records(OptionalPaginationResource, 30)

      filter = build_filter(OptionalPaginationResource, mode: :load_more, page_size: 10)
      state = build_mock_state(master_user())

      {:ok, page1} = RelationLoader.load_options(filter, state, page: 1)
      {:ok, page2} = RelationLoader.load_options(filter, state, page: 2)
      {:ok, page3} = RelationLoader.load_options(filter, state, page: 3)

      assert length(page1.options) == 10
      assert page1.has_more? == true

      assert length(page2.options) == 10
      assert page2.has_more? == true

      assert length(page3.options) == 10
      assert page3.has_more? == false
    end

    test "include_nil prepends nil option on first page - 30 items" do
      create_records(OptionalPaginationResource, 30)

      filter =
        build_filter(OptionalPaginationResource,
          mode: :load_more,
          page_size: 10,
          include_nil: true
        )

      state = build_mock_state(master_user())

      {:ok, result} = RelationLoader.load_options(filter, state, page: 1)

      assert hd(result.options) == {"(None)", "__nil__"}
      # 10 records + 1 nil option = 11
      assert length(result.options) == 11
    end

    test "include_nil does NOT prepend on subsequent pages - 30 items" do
      create_records(OptionalPaginationResource, 30)

      filter =
        build_filter(OptionalPaginationResource,
          mode: :load_more,
          page_size: 10,
          include_nil: true
        )

      state = build_mock_state(master_user())

      {:ok, page2} = RelationLoader.load_options(filter, state, page: 2)
      {:ok, page3} = RelationLoader.load_options(filter, state, page: 3)

      refute Enum.any?(page2.options, fn {_, v} -> v == "__nil__" end)
      refute Enum.any?(page3.options, fn {_, v} -> v == "__nil__" end)
      assert length(page2.options) == 10
      assert length(page3.options) == 10
    end
  end

  defp get_tenant_from_state(%{master_user?: true}), do: nil
  defp get_tenant_from_state(%{current_user: user}), do: Map.get(user, :site_id)
  defp get_tenant_from_state(_), do: nil
end

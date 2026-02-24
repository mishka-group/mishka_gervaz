defmodule MishkaGervaz.Form.Web.DataLoader.RelationLoaderTest do
  @moduledoc """
  Tests for form RelationLoader value_field support.

  Uses ETS-backed test resources from relation_loader_resources.ex.
  Verifies that the value_field option correctly changes which attribute
  is used as the option value (instead of always using record.id).
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Web.DataLoader.RelationLoader.Default, as: RelationLoader

  alias MishkaGervaz.Test.RelationLoader.{
    NoPaginationResource,
    OptionalPaginationResource,
    RequiredPaginationResource
  }

  defp master_user, do: %{id: "master-123", site_id: nil, role: :admin}

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
    end)

    :ok
  end

  defp build_field(resource, opts \\ []) do
    %{
      name: Keyword.get(opts, :name, :test_field),
      type: :relation,
      mode: Keyword.get(opts, :mode, :static),
      resource: resource,
      display_field: Keyword.get(opts, :display_field, :name),
      value_field: Keyword.get(opts, :value_field, nil),
      load_action: Keyword.get(opts, :load_action, :read),
      page_size: Keyword.get(opts, :page_size, 20),
      include_nil: Keyword.get(opts, :include_nil, false),
      search_field: Keyword.get(opts, :search_field, nil),
      load: Keyword.get(opts, :load, nil)
    }
  end

  defp build_state(user) do
    %{
      current_user: user,
      master_user?: user.site_id == nil
    }
  end

  # ============================================================================
  # load_options - default behavior (value_field: nil)
  # ============================================================================

  describe "load_options default (value_field: nil) uses record.id" do
    test "static mode returns {display, id} tuples" do
      records = create_records(NoPaginationResource, 3)
      field = build_field(NoPaginationResource)
      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      assert length(options) == 3
      ids = Enum.map(records, &to_string(&1.id))

      Enum.each(options, fn {label, value} ->
        assert is_binary(label)
        assert value in ids
      end)
    end

    test "paginated mode returns {display, id} tuples" do
      records = create_records(OptionalPaginationResource, 5)
      field = build_field(OptionalPaginationResource, mode: :load_more, page_size: 10)
      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      assert length(options) == 5
      ids = Enum.map(records, &to_string(&1.id))

      Enum.each(options, fn {_label, value} ->
        assert value in ids
      end)
    end
  end

  # ============================================================================
  # load_options - value_field set
  # ============================================================================

  describe "load_options with value_field uses specified attribute" do
    test "static mode returns {display, custom_value} tuples" do
      records =
        create_records(NoPaginationResource, 3, fn i -> %{name: "Cat #{i}", title: "T#{i}"} end)

      field = build_field(NoPaginationResource, value_field: :name)
      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      assert length(options) == 3
      names = Enum.map(records, &to_string(&1.name))

      Enum.each(options, fn {_label, value} ->
        assert value in names
      end)

      ids = Enum.map(records, &to_string(&1.id))

      Enum.each(options, fn {_label, value} ->
        refute value in ids
      end)
    end

    test "paginated mode returns {display, custom_value} tuples" do
      records =
        create_records(OptionalPaginationResource, 5, fn i ->
          %{name: "Item #{i}", title: "Title #{i}"}
        end)

      field =
        build_field(OptionalPaginationResource,
          mode: :load_more,
          page_size: 10,
          value_field: :title
        )

      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      assert length(options) == 5
      titles = Enum.map(records, &to_string(&1.title))

      Enum.each(options, fn {_label, value} ->
        assert value in titles
      end)
    end

    test "display_field and value_field can be different attributes" do
      create_records(NoPaginationResource, 2, fn i ->
        %{name: "Name #{i}", title: "Title #{i}"}
      end)

      field = build_field(NoPaginationResource, display_field: :name, value_field: :title)
      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      Enum.each(options, fn {label, value} ->
        assert String.starts_with?(label, "Name ")
        assert String.starts_with?(value, "Title ")
      end)
    end

    test "value_field with include_nil prepends nil option" do
      create_records(NoPaginationResource, 2, fn i -> %{name: "Cat #{i}"} end)

      field =
        build_field(NoPaginationResource, value_field: :name, include_nil: "No Selection")

      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      assert length(options) == 3
      assert hd(options) == {"No Selection", "__nil__"}

      Enum.each(tl(options), fn {_label, value} ->
        refute value == "__nil__"
      end)
    end

    test "value_field nil attribute falls back to record.id" do
      records =
        create_records(NoPaginationResource, 2, fn i -> %{name: "Item #{i}", title: nil} end)

      field = build_field(NoPaginationResource, value_field: :title)
      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      ids = Enum.map(records, &to_string(&1.id))

      Enum.each(options, fn {_label, value} ->
        assert value in ids
      end)
    end
  end

  # ============================================================================
  # search_options - value_field set
  # ============================================================================

  describe "search_options with value_field" do
    test "returns {display, custom_value} tuples matching search" do
      create_records(OptionalPaginationResource, 5, fn i -> %{name: "Alpha #{i}"} end)
      create_records(OptionalPaginationResource, 3, fn i -> %{name: "Beta #{i}"} end)

      field =
        build_field(OptionalPaginationResource,
          mode: :search,
          page_size: 20,
          value_field: :name,
          search_field: :name
        )

      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.search_options(field, state, "Alpha")

      assert length(options) == 5

      Enum.each(options, fn {label, value} ->
        assert String.contains?(label, "Alpha")
        assert String.contains?(value, "Alpha")
      end)
    end

    test "search without value_field uses record.id as value" do
      records = create_records(OptionalPaginationResource, 5, fn i -> %{name: "Alpha #{i}"} end)
      create_records(OptionalPaginationResource, 3, fn i -> %{name: "Beta #{i}"} end)

      field =
        build_field(OptionalPaginationResource,
          mode: :search,
          page_size: 20,
          search_field: :name
        )

      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.search_options(field, state, "Alpha")

      assert length(options) == 5
      ids = Enum.map(records, &to_string(&1.id))

      Enum.each(options, fn {_label, value} ->
        assert value in ids
      end)
    end
  end

  # ============================================================================
  # resolve_selected - value_field set
  # ============================================================================

  describe "resolve_selected with value_field" do
    test "resolves by value_field attribute instead of :id" do
      records =
        create_records(NoPaginationResource, 5, fn i -> %{name: "Category #{i}"} end)

      selected_names = records |> Enum.take(3) |> Enum.map(&to_string(&1.name))
      field = build_field(NoPaginationResource, value_field: :name)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, selected_names)

      assert length(matched) == 3

      Enum.each(matched, fn {label, value} ->
        assert is_binary(label)
        assert value in selected_names
      end)
    end

    test "resolve_selected without value_field resolves by :id" do
      records = create_records(NoPaginationResource, 5)
      selected_ids = records |> Enum.take(3) |> Enum.map(&to_string(&1.id))

      field = build_field(NoPaginationResource)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, selected_ids)

      assert length(matched) == 3

      Enum.each(matched, fn {_label, value} ->
        assert value in selected_ids
      end)
    end

    test "resolve_selected with value_field returns empty for non-matching values" do
      create_records(NoPaginationResource, 3, fn i -> %{name: "Cat #{i}"} end)

      field = build_field(NoPaginationResource, value_field: :name)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, ["nonexistent_value"])

      assert matched == []
    end

    test "resolve_selected with value_field handles empty list" do
      field = build_field(NoPaginationResource, value_field: :name)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, [])
      assert matched == []
    end

    test "resolve_selected with value_field handles nil" do
      field = build_field(NoPaginationResource, value_field: :name)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, nil)
      assert matched == []
    end

    test "resolve_selected fallback with value_field on required pagination resource" do
      records =
        create_records(RequiredPaginationResource, 3, fn i -> %{name: "ReqItem #{i}"} end)

      selected_names = records |> Enum.take(2) |> Enum.map(&to_string(&1.name))

      field = build_field(RequiredPaginationResource, value_field: :name)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, selected_names)

      assert length(matched) == 2

      Enum.each(matched, fn {_label, value} ->
        assert value in selected_names
      end)
    end

    test "resolve_selected fallback without value_field on required pagination resource" do
      records = create_records(RequiredPaginationResource, 3)
      selected_ids = records |> Enum.take(2) |> Enum.map(&to_string(&1.id))

      field = build_field(RequiredPaginationResource)
      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, selected_ids)

      assert length(matched) == 2

      Enum.each(matched, fn {_label, value} ->
        assert value in selected_ids
      end)
    end
  end

  # ============================================================================
  # Static options (no resource) - value_field has no effect
  # ============================================================================

  describe "static options without resource" do
    test "value_field is ignored when no resource is set" do
      static_options = [{"Option A", "val_a"}, {"Option B", "val_b"}]

      field = %{
        name: :test_field,
        type: :relation,
        resource: nil,
        options: static_options,
        value_field: :some_field,
        mode: :static
      }

      state = build_state(master_user())

      {:ok, options, false} = RelationLoader.load_options(field, state)

      assert options == static_options
    end

    test "resolve_selected with static options ignores value_field" do
      static_options = [{"Option A", "val_a"}, {"Option B", "val_b"}, {"Option C", "val_c"}]

      field = %{
        name: :test_field,
        type: :relation,
        resource: nil,
        options: static_options,
        value_field: :some_field,
        mode: :static
      }

      state = build_state(master_user())

      {:ok, matched} = RelationLoader.resolve_selected(field, state, ["val_a", "val_c"])

      assert length(matched) == 2
      assert {"Option A", "val_a"} in matched
      assert {"Option C", "val_c"} in matched
    end
  end

  # ============================================================================
  # Pagination boundary with value_field
  # ============================================================================

  describe "pagination with value_field" do
    test "paginated load_more with value_field respects page boundaries" do
      create_records(OptionalPaginationResource, 15, fn i ->
        %{name: "Page Item #{i}"}
      end)

      field =
        build_field(OptionalPaginationResource,
          mode: :load_more,
          page_size: 5,
          value_field: :name
        )

      state = build_state(master_user())

      {:ok, page1, true} = RelationLoader.load_options(field, state, page: 1)
      {:ok, page2, true} = RelationLoader.load_options(field, state, page: 2)
      {:ok, page3, false} = RelationLoader.load_options(field, state, page: 3)

      assert length(page1) == 5
      assert length(page2) == 5
      assert length(page3) == 5

      all_values = Enum.map(page1 ++ page2 ++ page3, &elem(&1, 1))
      assert Enum.all?(all_values, &String.starts_with?(&1, "Page Item "))

      refute Enum.any?(all_values, fn v ->
               String.match?(v, ~r/^[0-9a-f]{8}-/)
             end)
    end

    test "include_nil only on first page with value_field" do
      create_records(OptionalPaginationResource, 10, fn i ->
        %{name: "Item #{i}"}
      end)

      field =
        build_field(OptionalPaginationResource,
          mode: :load_more,
          page_size: 5,
          value_field: :name,
          include_nil: "None"
        )

      state = build_state(master_user())

      {:ok, page1, true} = RelationLoader.load_options(field, state, page: 1)
      {:ok, page2, false} = RelationLoader.load_options(field, state, page: 2)

      assert hd(page1) == {"None", "__nil__"}
      assert length(page1) == 6

      refute Enum.any?(page2, fn {_, v} -> v == "__nil__" end)
      assert length(page2) == 5
    end
  end
end

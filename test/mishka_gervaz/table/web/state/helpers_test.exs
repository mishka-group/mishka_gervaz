defmodule MishkaGervaz.Table.Web.State.HelpersTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Table.Web.State.Helpers`.

  These pin the data-shape helper contracts that the `__using__` macro and
  any user state override rely on. Integration tests in `state_test.exs`
  cover the same paths transitively, but a regression in any single clause
  here would show up there only as a hard-to-localize symptom.

  `hydrate_filter/3`, `resolve_and_store_labels/4`, and
  `resolve_relation_loader/1` go through `RelationLoader` and are exercised
  via the relation-loader integration tests rather than here.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.State.Helpers

  describe "extract_selected_ids/2" do
    test "wraps single value into a stringified list" do
      assert Helpers.extract_selected_ids(%{author_id: "abc-123"}, :author_id) == ["abc-123"]
    end

    test "passes a list through to string list" do
      assert Helpers.extract_selected_ids(%{tag_ids: ["a", :b, 1]}, :tag_ids) ==
               ["a", "b", "1"]
    end

    test "drops empty strings and 'nil'" do
      assert Helpers.extract_selected_ids(
               %{author_id: ["", "nil", "real", nil]},
               :author_id
             ) == ["real"]
    end

    test "returns [] when filter key is missing" do
      assert Helpers.extract_selected_ids(%{}, :author_id) == []
    end
  end

  describe "get_page_size/1, get_page_size_options/1, get_max_page_size/1" do
    test "extracts values when pagination is present" do
      cfg = %{pagination: %{page_size: 25, page_size_options: [25, 50], max_page_size: 100}}
      assert Helpers.get_page_size(cfg) == 25
      assert Helpers.get_page_size_options(cfg) == [25, 50]
      assert Helpers.get_max_page_size(cfg) == 100
    end

    test "returns nil when pagination key missing" do
      assert Helpers.get_page_size(%{}) == nil
      assert Helpers.get_page_size_options(%{}) == nil
      assert Helpers.get_max_page_size(%{}) == nil
    end
  end

  describe "get_layout_header/1, get_layout_footer/1, get_layout_notices/1" do
    test "returns map when present" do
      cfg = %{layout: %{header: %{title: "T"}, footer: %{content: "C"}, notices: [%{name: :a}]}}
      assert Helpers.get_layout_header(cfg) == %{title: "T"}
      assert Helpers.get_layout_footer(cfg) == %{content: "C"}
      assert Helpers.get_layout_notices(cfg) == [%{name: :a}]
    end

    test "returns defaults when missing or wrong shape" do
      assert Helpers.get_layout_header(%{}) == nil
      assert Helpers.get_layout_footer(%{}) == nil
      assert Helpers.get_layout_notices(%{}) == []
      assert Helpers.get_layout_header(%{layout: %{header: "string"}}) == nil
      assert Helpers.get_layout_notices(%{layout: %{notices: nil}}) == []
    end
  end

  describe "get_filter_groups/1, get_filter_mode/1" do
    test "groups returns list, defaults to []" do
      assert Helpers.get_filter_groups(%{filter_groups: [%{name: :a}]}) == [%{name: :a}]
      assert Helpers.get_filter_groups(%{}) == []
      assert Helpers.get_filter_groups(%{filter_groups: nil}) == []
    end

    test "mode returns atom, defaults to :inline" do
      assert Helpers.get_filter_mode(%{presentation: %{filter_mode: :modal}}) == :modal
      assert Helpers.get_filter_mode(%{}) == :inline
      assert Helpers.get_filter_mode(%{presentation: %{filter_mode: "modal"}}) == :inline
    end
  end

  describe "get_pagination_ui/1" do
    test "passes struct through" do
      ui = struct(MishkaGervaz.Table.Entities.Pagination.Ui)
      assert Helpers.get_pagination_ui(%{pagination: %{ui: ui}}) == ui
    end

    test "wraps plain map into the Ui struct" do
      result = Helpers.get_pagination_ui(%{pagination: %{ui: %{}}})
      assert is_struct(result, MishkaGervaz.Table.Entities.Pagination.Ui)
    end

    test "returns default Ui struct when missing" do
      result = Helpers.get_pagination_ui(%{})
      assert is_struct(result, MishkaGervaz.Table.Entities.Pagination.Ui)
    end
  end

  describe "get_sortable_columns/1" do
    test "names only the sortable ones" do
      columns = [
        %{name: :title, sortable: true},
        %{name: :body, sortable: false},
        %{name: :created_at, sortable: true}
      ]

      assert Helpers.get_sortable_columns(columns) == [:title, :created_at]
    end

    test "[] when none sortable" do
      assert Helpers.get_sortable_columns([%{name: :a, sortable: false}]) == []
    end
  end

  describe "build_sort_field_map/1" do
    test "uses explicit :sort_field when set" do
      columns = [%{name: :author_name, sortable: true, sort_field: [:author, :name]}]
      assert Helpers.build_sort_field_map(columns) == %{author_name: [:author, :name]}
    end

    test "falls back to [name] when :sort_field is missing/empty/nil" do
      columns = [
        %{name: :title, sortable: true},
        %{name: :body, sortable: true, sort_field: []},
        %{name: :age, sortable: true, sort_field: nil}
      ]

      assert Helpers.build_sort_field_map(columns) ==
               %{title: [:title], body: [:body], age: [:age]}
    end

    test "skips non-sortable columns" do
      columns = [%{name: :a, sortable: true}, %{name: :b, sortable: false}]
      assert Helpers.build_sort_field_map(columns) == %{a: [:a]}
    end
  end

  describe "get_supports_archive/2, get_archive_visible/1" do
    test "enabled + restricted requires master" do
      cfg = %{source: %{archive: %{enabled: true, restricted: true}}}
      assert Helpers.get_supports_archive(cfg, true)
      refute Helpers.get_supports_archive(cfg, false)
    end

    test "enabled (unrestricted) any user" do
      cfg = %{source: %{archive: %{enabled: true}}}
      assert Helpers.get_supports_archive(cfg, false)
      assert Helpers.get_supports_archive(cfg, true)
    end

    test "disabled = false regardless of master" do
      cfg = %{source: %{archive: %{enabled: false}}}
      refute Helpers.get_supports_archive(cfg, true)
      refute Helpers.get_supports_archive(cfg, false)
    end

    test "no archive block = false" do
      refute Helpers.get_supports_archive(%{}, true)
    end

    test "visible flag overrides default-true" do
      assert Helpers.get_archive_visible(%{source: %{archive: %{visible: true}}})
      refute Helpers.get_archive_visible(%{source: %{archive: %{visible: false}}})
      assert Helpers.get_archive_visible(%{})
      assert Helpers.get_archive_visible(%{source: %{archive: %{visible: "yes"}}})
    end
  end

  describe "generate_stream_name/1" do
    test "derives `<snake_module>_stream` atom" do
      assert Helpers.generate_stream_name(MishkaGervaz.Test.Post) == :post_stream
    end
  end

  describe "get_default_sort/2" do
    test "explicit default_sort wins" do
      cfg = %{columns: %{default_sort: [{:title, :asc}]}}
      assert Helpers.get_default_sort(cfg, []) == [{:title, :asc}]
    end

    test "falls back to inserted_at desc when present + sortable" do
      cfg = %{}
      columns = [%{name: :inserted_at, sortable: true}]
      assert Helpers.get_default_sort(cfg, columns) == [{:inserted_at, :desc}]
    end

    test "[] when nothing matches" do
      assert Helpers.get_default_sort(%{}, [%{name: :title, sortable: true}]) == []
      assert Helpers.get_default_sort(%{}, []) == []
    end

    test "explicit empty list falls through to inserted_at heuristic" do
      cfg = %{columns: %{default_sort: []}}
      columns = [%{name: :inserted_at, sortable: true}]
      assert Helpers.get_default_sort(cfg, columns) == [{:inserted_at, :desc}]
    end
  end

  describe "resolve_url_sync/2, resolve_access/2" do
    test "nil resource → default" do
      assert Helpers.resolve_url_sync(nil, :sentinel_url) == :sentinel_url
      assert Helpers.resolve_access(nil, :sentinel_access) == :sentinel_access
    end
  end
end

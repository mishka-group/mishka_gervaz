defmodule MishkaGervaz.Table.Web.VirtualFilterTest do
  @moduledoc """
  Tests for virtual, load, and apply filter options.

  These features exist in the DSL schema but had zero test coverage.
  This test file verifies they work end-to-end:

  - `virtual: true` — filter with no database column
  - `apply` — custom function that overrides default query building
  - `load` — custom function that modifies relation option loading
  - `resource` — explicit resource for loading filter options (virtual relations)
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Table.Web.DataLoader.QueryBuilder
  alias MishkaGervaz.Table.Web.DataLoader.RelationLoader
  alias MishkaGervaz.ResourceInfo

  alias MishkaGervaz.Test.VirtualFilter.{
    TagResource,
    ArticleResource
  }

  require Ash.Query

  defp master_user, do: %{id: "master-123", site_id: nil, role: :admin}

  defp clear_ets(resource) do
    try do
      Ash.DataLayer.Ets.stop(resource)
    rescue
      _ -> :ok
    end
  end

  setup do
    on_exit(fn ->
      clear_ets(TagResource)
      clear_ets(ArticleResource)
    end)

    :ok
  end

  # ── DSL Compilation ──────────────────────────────────────────────

  describe "DSL compilation — virtual, load, apply stored correctly" do
    test "virtual filter has virtual: true" do
      filter = ResourceInfo.filter(ArticleResource, :tag)

      assert filter.virtual == true
    end

    test "non-virtual filter has virtual: false" do
      filter = ResourceInfo.filter(ArticleResource, :category)

      assert filter.virtual == false
    end

    test "filter with apply has a 3-arity function stored" do
      filter = ResourceInfo.filter(ArticleResource, :tag)

      assert is_function(filter.apply, 3)
    end

    test "filter without apply has nil" do
      filter = ResourceInfo.filter(ArticleResource, :search)

      assert is_nil(filter.apply)
    end

    test "relation filter with load has a 2-arity function stored" do
      filter = ResourceInfo.filter(ArticleResource, :tag_id)

      assert is_function(filter.load, 2)
    end

    test "filter without load has nil" do
      filter = ResourceInfo.filter(ArticleResource, :search)

      assert is_nil(filter.load)
    end

    test "virtual relation filter has explicit resource set" do
      filter = ResourceInfo.filter(ArticleResource, :external_tag)

      assert filter.resource == TagResource
      assert filter.virtual == true
    end

    test "virtual boolean filter compiles correctly" do
      filter = ResourceInfo.filter(ArticleResource, :has_author)

      assert filter.virtual == true
      assert filter.type == :boolean
      assert is_function(filter.apply, 3)
    end

    test "virtual relation filter with load + apply compiles correctly" do
      filter = ResourceInfo.filter(ArticleResource, :external_tag)

      assert filter.virtual == true
      assert filter.type == :relation
      assert filter.resource == TagResource
      assert filter.mode == :static
      assert is_function(filter.load, 2)
      assert is_function(filter.apply, 3)
    end
  end

  # ── Apply Function — QueryBuilder ────────────────────────────────

  describe "apply function — virtual select filter" do
    test "virtual select filter with apply filters data correctly" do
      Ash.create!(ArticleResource, %{title: "Elixir Guide", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Phoenix Tutorial", category: "phoenix"})
      Ash.create!(ArticleResource, %{title: "Ash Basics", category: "ash"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "elixir"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Elixir Guide"
    end

    test "virtual select filter with different value returns correct results" do
      Ash.create!(ArticleResource, %{title: "Elixir 1", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Elixir 2", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Phoenix 1", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "phoenix"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Phoenix 1"
    end

    test "virtual filter returns no results when value doesn't match" do
      Ash.create!(ArticleResource, %{title: "Elixir Guide", category: "elixir"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "nonexistent"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 0
    end
  end

  describe "apply function — non-virtual select filter" do
    test "custom apply overrides default type_module behavior" do
      Ash.create!(ArticleResource, %{title: "Tech Article", category: "tech"})
      Ash.create!(ArticleResource, %{title: "Science Paper", category: "science"})
      Ash.create!(ArticleResource, %{title: "Art Piece", category: "arts"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{category: "tech"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).category == "tech"
    end

    test "apply takes precedence over type_module build_query" do
      Ash.create!(ArticleResource, %{title: "Item 1", category: "science"})
      Ash.create!(ArticleResource, %{title: "Item 2", category: "science"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{category: "science"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 2
    end
  end

  describe "apply function — virtual boolean filter" do
    test "boolean apply with true filters records with author" do
      Ash.create!(ArticleResource, %{title: "With Author", author_name: "Alice"})
      Ash.create!(ArticleResource, %{title: "No Author", author_name: nil})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{has_author: true})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "With Author"
    end

    test "boolean apply with false filters records without author" do
      Ash.create!(ArticleResource, %{title: "With Author", author_name: "Alice"})
      Ash.create!(ArticleResource, %{title: "No Author", author_name: nil})
      Ash.create!(ArticleResource, %{title: "Also No Author"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{has_author: false})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 2

      titles = Enum.map(result.results, & &1.title) |> Enum.sort()
      assert titles == ["Also No Author", "No Author"]
    end
  end

  describe "apply function — virtual relation filter" do
    test "virtual relation filter with apply modifies main query" do
      tag = Ash.create!(TagResource, %{name: "Elixir"})
      tag_id_str = to_string(tag.id)

      Ash.create!(ArticleResource, %{title: "Match", category: tag_id_str})
      Ash.create!(ArticleResource, %{title: "No Match", category: "other"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{external_tag: tag_id_str})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Match"
    end
  end

  describe "apply function — multiple filters combined" do
    test "virtual filter + regular filter combined" do
      Ash.create!(ArticleResource, %{
        title: "Elixir Tech",
        category: "elixir",
        author_name: "Alice"
      })

      Ash.create!(ArticleResource, %{title: "Elixir None", category: "elixir", author_name: nil})
      Ash.create!(ArticleResource, %{title: "Phoenix Tech", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{tag: "elixir", has_author: true}
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Elixir Tech"
    end

    test "two virtual filters combined" do
      Ash.create!(ArticleResource, %{
        title: "Match Both",
        category: "elixir",
        author_name: "Bob"
      })

      Ash.create!(ArticleResource, %{title: "Match Tag Only", category: "elixir"})

      Ash.create!(ArticleResource, %{
        title: "Match Author Only",
        category: "other",
        author_name: "Eve"
      })

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{tag: "elixir", has_author: true}
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Match Both"
    end

    test "text filter + virtual filter combined" do
      Ash.create!(ArticleResource, %{title: "Elixir Guide", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Elixir Tutorial", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Phoenix Guide", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{search: "Guide", tag: "elixir"}
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Elixir Guide"
    end
  end

  describe "apply function — context argument" do
    test "build_apply_context returns populated map from state" do
      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "elixir"})
      state = %{state | path_params: %{workspace_version_id: "some-uuid"}}

      context = QueryBuilder.Default.build_apply_context(state)

      assert context.path_params == %{workspace_version_id: "some-uuid"}
      assert context.current_user == master_user()
      assert context.master_user? == true
      assert context.filter_values == %{tag: "elixir"}
      assert context.archive_status == :active
    end

    test "build_apply_context returns empty map for nil" do
      context = QueryBuilder.Default.build_apply_context(nil)

      assert context == %{}
    end

    test "apply receives context with state data through QueryBuilder flow" do
      Ash.create!(ArticleResource, %{title: "Test", category: "elixir"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "elixir"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
    end

    test "apply function is invoked from actual QueryBuilder flow" do
      Ash.create!(ArticleResource, %{title: "Test", category: "elixir"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "elixir"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
    end
  end

  # ── Load Function — RelationLoader ────────────────────────────────

  describe "load function — relation filter with custom load" do
    test "custom load function sorts options alphabetically" do
      Ash.create!(TagResource, %{name: "Zebra"})
      Ash.create!(TagResource, %{name: "Apple"})
      Ash.create!(TagResource, %{name: "Mango"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :tag_id))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert names == ["Apple", "Mango", "Zebra"]
    end

    test "load function is called (not skipped) for relation filters" do
      Ash.create!(TagResource, %{name: "Tag A"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :tag_id))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      assert length(result.options) == 1
      assert result.page == 1
    end
  end

  describe "load function — virtual relation filter" do
    test "virtual relation loads options from explicit resource" do
      Ash.create!(TagResource, %{name: "Tag 1"})
      Ash.create!(TagResource, %{name: "Tag 2"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :external_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      assert length(result.options) == 2
    end

    test "virtual relation load function sorts options descending" do
      Ash.create!(TagResource, %{name: "Alpha"})
      Ash.create!(TagResource, %{name: "Beta"})
      Ash.create!(TagResource, %{name: "Gamma"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :external_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert names == ["Gamma", "Beta", "Alpha"]
    end

    test "virtual relation filter resolves resource from explicit resource option" do
      filter = ResourceInfo.filter(ArticleResource, :external_tag)

      assert filter.resource == TagResource
    end
  end

  describe "load function — receives correct arguments" do
    test "load function receives an Ash.Query as first argument" do
      test_pid = self()
      filter = ResourceInfo.filter(ArticleResource, :tag_id)

      query = Ash.Query.new(TagResource)

      result = filter.load.(query, %{master_user?: true, current_user: master_user()})
      send(test_pid, {:load_result, result})

      assert_received {:load_result, result}
      assert is_struct(result, Ash.Query)
    end

    test "load function receives state as second argument" do
      test_pid = self()

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :tag_id))

      query = Ash.Query.new(TagResource)
      result = filter.load.(query, state)

      send(test_pid, {:load_done, result})

      assert_received {:load_done, _}
    end
  end

  # ── Integration: Apply + Load Together ────────────────────────────

  describe "integration — virtual relation filter with load + apply" do
    test "load provides sorted options, apply filters main query" do
      tag1 = Ash.create!(TagResource, %{name: "Zebra"})
      tag2 = Ash.create!(TagResource, %{name: "Apple"})

      Ash.create!(ArticleResource, %{title: "Article 1", category: to_string(tag1.id)})
      Ash.create!(ArticleResource, %{title: "Article 2", category: to_string(tag2.id)})
      Ash.create!(ArticleResource, %{title: "Article 3", category: "unrelated"})

      state = State.init("test-id", ArticleResource, master_user())

      # Test load: options should be sorted name desc (Zebra, Apple)
      filter = Enum.find(state.static.filters, &(&1.name == :external_tag))
      {:ok, load_result} = RelationLoader.Default.load_options(filter, state)

      names = Enum.map(load_result.options, fn {label, _id} -> label end)
      assert names == ["Zebra", "Apple"]

      # Test apply: selecting tag1 should filter to articles with category = tag1.id
      state = State.update(state, filter_values: %{external_tag: to_string(tag1.id)})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Article 1"
    end
  end

  # ── Context-Aware Apply ─────────────────────────────────────────

  describe "apply function — context-aware with path_params" do
    test "apply uses context.path_params when workspace_version_id is present" do
      Ash.create!(ArticleResource, %{title: "Match", category: "version-123"})
      Ash.create!(ArticleResource, %{title: "No Match", category: "other"})

      state = State.init("test-id", ArticleResource, master_user())
      state = %{state | path_params: %{workspace_version_id: "version-123"}}
      state = State.update(state, filter_values: %{path_scoped: "scoped"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Match"
    end

    test "apply falls back to value when path_params has no workspace_version_id" do
      Ash.create!(ArticleResource, %{title: "Scoped", category: "scoped"})
      Ash.create!(ArticleResource, %{title: "Unscoped", category: "unscoped"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{path_scoped: "scoped"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Scoped"
    end

    test "apply receives current_user in context" do
      Ash.create!(ArticleResource, %{title: "Test", category: "elixir"})

      user = master_user()
      state = State.init("test-id", ArticleResource, user)
      state = State.update(state, filter_values: %{tag: "elixir"})

      context = QueryBuilder.Default.build_apply_context(state)

      assert context.current_user == user
      assert context.master_user? == true
    end

    test "apply receives filter_values in context" do
      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: "elixir", has_author: true})

      context = QueryBuilder.Default.build_apply_context(state)

      assert context.filter_values == %{tag: "elixir", has_author: true}
    end
  end

  # ── Context-Aware Load ────────────────────────────────────────

  describe "load function — context-aware master vs tenant" do
    test "load sorts ascending for master user" do
      Ash.create!(TagResource, %{name: "Zebra"})
      Ash.create!(TagResource, %{name: "Apple"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :context_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert names == ["Apple", "Zebra"]
    end

    test "load sorts descending for non-master user" do
      Ash.create!(TagResource, %{name: "Zebra"})
      Ash.create!(TagResource, %{name: "Apple"})

      tenant_user = %{id: "tenant-123", site_id: "site-456", role: :editor}
      state = State.init("test-id", ArticleResource, tenant_user)
      filter = Enum.find(state.static.filters, &(&1.name == :context_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert names == ["Zebra", "Apple"]
    end
  end

  # ── Source + Apply Interaction ─────────────────────────────────

  describe "source + apply interaction" do
    test "apply takes precedence over source field mapping" do
      Ash.create!(ArticleResource, %{title: "Target Title", category: "irrelevant"})
      Ash.create!(ArticleResource, %{title: "Other", category: "Target Title"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{source_override: "Target Title"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Target Title"
    end

    test "source field is ignored when apply is present" do
      Ash.create!(ArticleResource, %{title: "A", category: "match_me"})
      Ash.create!(ArticleResource, %{title: "match_me", category: "B"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{source_override: "match_me"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "match_me"
    end
  end

  # ── Display Field 2-Arity ─────────────────────────────────────

  describe "display_field as 2-arity function" do
    test "master user sees prefixed labels" do
      Ash.create!(TagResource, %{name: "Elixir"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :display_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      labels = Enum.map(result.options, fn {label, _id} -> label end)
      assert hd(labels) == "Master: Elixir"
    end

    test "non-master user sees plain labels" do
      Ash.create!(TagResource, %{name: "Elixir"})

      tenant_user = %{id: "tenant-123", site_id: "site-456", role: :editor}
      state = State.init("test-id", ArticleResource, tenant_user)
      filter = Enum.find(state.static.filters, &(&1.name == :display_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      labels = Enum.map(result.options, fn {label, _id} -> label end)
      assert hd(labels) == "Elixir"
    end

    test "display_field 2-arity function is correctly stored in DSL" do
      filter = ResourceInfo.filter(ArticleResource, :display_tag)

      assert is_function(filter.display_field, 2)
    end
  end

  # ── Load with Search Mode ─────────────────────────────────────

  describe "load with search mode" do
    test "search_options applies custom load and search term" do
      Ash.create!(TagResource, %{name: "Alpha"})
      Ash.create!(TagResource, %{name: "Beta"})
      Ash.create!(TagResource, %{name: "Alphabet"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :searchable_tag))

      {:ok, result} = RelationLoader.Default.search_options(filter, state, "Alph")

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert "Alpha" in names
      assert "Alphabet" in names
      refute "Beta" in names
    end

    test "search_options with custom load respects sort order" do
      Ash.create!(TagResource, %{name: "Zeta Search"})
      Ash.create!(TagResource, %{name: "Alpha Search"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :searchable_tag))

      {:ok, result} = RelationLoader.Default.search_options(filter, state, "Search")

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert names == ["Alpha Search", "Zeta Search"]
    end

    test "load_more_options applies custom load" do
      Ash.create!(TagResource, %{name: "Zebra"})
      Ash.create!(TagResource, %{name: "Apple"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :searchable_tag))

      {:ok, result} = RelationLoader.Default.load_more_options(filter, state)

      names = Enum.map(result.options, fn {label, _id} -> label end)
      assert names == ["Apple", "Zebra"]
    end

    test "search mode filter compiles with correct mode" do
      filter = ResourceInfo.filter(ArticleResource, :searchable_tag)

      assert filter.mode == :search
      assert filter.page_size == 5
      assert filter.min_chars == 1
      assert is_function(filter.load, 2)
      assert is_function(filter.apply, 3)
    end
  end

  # ── depends_on — Cascading Filter Behavior ──────────────────────

  describe "depends_on — DSL config" do
    test "child filter stores depends_on reference" do
      filter = ResourceInfo.filter(ArticleResource, :city)
      assert filter.depends_on == :region
    end

    test "parent filter has no depends_on" do
      filter = ResourceInfo.filter(ArticleResource, :region)
      assert filter.depends_on == nil
    end

    test "child filter stores disabled_prompt in ui" do
      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :city))
      assert filter.ui.disabled_prompt == "Select region first"
    end
  end

  describe "depends_on — runtime query behavior" do
    test "parent and child both apply when both have values" do
      Ash.create!(ArticleResource, %{title: "Match", category: "us", author_name: "ny"})
      Ash.create!(ArticleResource, %{title: "Wrong Region", category: "eu", author_name: "ny"})
      Ash.create!(ArticleResource, %{title: "Wrong City", category: "us", author_name: "london"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{region: "us", city: "ny"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Match"
    end

    test "child filter still applies if it has value (query builder ignores depends_on)" do
      Ash.create!(ArticleResource, %{title: "Target", category: "us", author_name: "ny"})
      Ash.create!(ArticleResource, %{title: "Other", category: "eu", author_name: "london"})

      # Only child value, no parent — query builder doesn't check depends_on
      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{city: "ny"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).author_name == "ny"
    end

    test "parent alone filters correctly without child" do
      Ash.create!(ArticleResource, %{title: "US Article", category: "us"})
      Ash.create!(ArticleResource, %{title: "EU Article", category: "eu"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{region: "us"})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "US Article"
    end

    test "depends_on disabling logic — child disabled when parent empty" do
      # Test the has_value? logic that filter_disabled? relies on
      assert MishkaGervaz.Helpers.has_value?(nil) == false
      assert MishkaGervaz.Helpers.has_value?("") == false
      assert MishkaGervaz.Helpers.has_value?([]) == false
      assert MishkaGervaz.Helpers.has_value?("us") == true
      assert MishkaGervaz.Helpers.has_value?(["a"]) == true
    end
  end

  # ── Bridge Pattern — No-op Apply with Value Consumption ────────

  describe "bridge pattern — no-op apply" do
    test "bridge filter's apply returns query unchanged (no filter added)" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "B", category: "phoenix"})

      tag = Ash.create!(TagResource, %{name: "Bridge Tag"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{bridge_tag: tag.id})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # No-op apply means all records returned despite bridge_tag having a value
      assert result.count == 2
    end

    test "consumer filter reads bridge value from context.filter_values" do
      Ash.create!(ArticleResource, %{title: "Match", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "No Match", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{bridge_tag: "elixir", bridge_consumer: true}
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # bridge_consumer reads bridge_tag="elixir" from context and filters category
      assert result.count == 1
      assert hd(result.results).title == "Match"
    end

    test "consumer filter handles missing bridge value gracefully" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "B", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())
      # bridge_consumer is true but bridge_tag is absent
      state = State.update(state, filter_values: %{bridge_consumer: true})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # No bridge value → consumer returns query unchanged → all records
      assert result.count == 2
    end

    test "bridge filter options load from resource" do
      Ash.create!(TagResource, %{name: "Tag A"})
      Ash.create!(TagResource, %{name: "Tag B"})

      state = State.init("test-id", ArticleResource, master_user())
      filter = Enum.find(state.static.filters, &(&1.name == :bridge_tag))

      {:ok, result} = RelationLoader.Default.load_options(filter, state)

      assert length(result.options) == 2
      labels = Enum.map(result.options, fn {label, _id} -> label end)
      assert "Tag A" in labels
      assert "Tag B" in labels
    end
  end

  # ── Multi-Select Bridge — List Values in Context ───────────────

  describe "multi-select bridge — list values in apply context" do
    test "list value from multi-select is accessible and filters correctly" do
      Ash.create!(ArticleResource, %{title: "Elixir Post", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Phoenix Post", category: "phoenix"})
      Ash.create!(ArticleResource, %{title: "Ash Post", category: "ash"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{
            multi_bridge: ["elixir", "phoenix"],
            multi_consumer: true
          }
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # multi_consumer reads list ["elixir", "phoenix"] from context and filters category in list
      assert result.count == 2
      titles = Enum.map(result.results, & &1.title) |> Enum.sort()
      assert titles == ["Elixir Post", "Phoenix Post"]
    end

    test "single-element list from multi-select bridge works" do
      Ash.create!(ArticleResource, %{title: "Elixir Post", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "Phoenix Post", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{multi_bridge: ["elixir"], multi_consumer: true}
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Elixir Post"
    end

    test "empty list from multi-select bridge returns all records" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "B", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{multi_bridge: [], multi_consumer: true})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # Empty list → consumer returns query unchanged
      assert result.count == 2
    end

    test "multi-select bridge no-op apply returns all records" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "B", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{multi_bridge: ["elixir", "phoenix"]})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      # multi_bridge has no-op apply → all records returned
      assert result.count == 2
    end
  end

  # ── Edge Cases ────────────────────────────────────────────────────

  describe "edge cases" do
    test "virtual filter without filter_values does not affect query" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "B", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 2
    end

    test "nil parsed value is skipped — apply function not called" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "B", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: nil})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 2
    end

    test "empty string parsed to nil is skipped — apply function not called" do
      Ash.create!(ArticleResource, %{title: "A", category: "elixir"})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag: ""})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
    end

    test "virtual filter with apply works alongside sorting" do
      Ash.create!(ArticleResource, %{title: "Z Article", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "A Article", category: "elixir"})
      Ash.create!(ArticleResource, %{title: "M Article", category: "phoenix"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{tag: "elixir"},
          sort_fields: [{:title, :asc}]
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10])

      titles = Enum.map(result.results, & &1.title)
      assert titles == ["A Article", "Z Article"]
    end

    test "relation filter with load but no apply uses type_module for query building" do
      tag = Ash.create!(TagResource, %{name: "Test Tag"})

      Ash.create!(ArticleResource, %{title: "Tagged", tag_id: tag.id})
      Ash.create!(ArticleResource, %{title: "Untagged", tag_id: nil})

      state = State.init("test-id", ArticleResource, master_user())
      state = State.update(state, filter_values: %{tag_id: to_string(tag.id)})

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Tagged"
    end

    test "multiple apply filters do not interfere with each other" do
      Ash.create!(ArticleResource, %{
        title: "Full Match",
        category: "tech",
        author_name: "Alice"
      })

      Ash.create!(ArticleResource, %{title: "Category Only", category: "tech"})
      Ash.create!(ArticleResource, %{title: "Author Only", category: "other", author_name: "Bob"})

      state = State.init("test-id", ArticleResource, master_user())

      state =
        State.update(state,
          filter_values: %{category: "tech", has_author: true}
        )

      query = QueryBuilder.Default.build_query(state)
      result = Ash.read!(query, page: [offset: 0, limit: 10, count: true])

      assert result.count == 1
      assert hd(result.results).title == "Full Match"
    end
  end
end

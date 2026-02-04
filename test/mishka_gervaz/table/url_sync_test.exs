defmodule MishkaGervaz.Table.UrlSyncTest do
  @moduledoc """
  Tests for the UrlSync module.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.UrlSync

  describe "encode/2 without prefix" do
    test "encodes filters without prefix" do
      state = %{filter_values: %{status: "active", category: "news"}}
      config = %{params: [:filters], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["filter_status"] == "active"
      assert result["filter_category"] == "news"
    end

    test "encodes sort without prefix" do
      state = %{filter_values: %{}, sort_fields: [{:inserted_at, :desc}]}
      config = %{params: [:sort], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["sort"] == "inserted_at:desc"
    end

    test "encodes multiple sort fields without prefix" do
      state = %{filter_values: %{}, sort_fields: [{:name, :asc}, {:inserted_at, :desc}]}
      config = %{params: [:sort], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["sort"] == "name:asc,inserted_at:desc"
    end

    test "encodes page without prefix" do
      state = %{filter_values: %{}, page: 5}
      config = %{params: [:page], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["page"] == "5"
    end

    test "does not encode page 1" do
      state = %{filter_values: %{}, page: 1}
      config = %{params: [:page], prefix: nil}

      result = UrlSync.encode(state, config)

      refute Map.has_key?(result, "page")
    end

    test "encodes search without prefix" do
      state = %{filter_values: %{search: "hello world"}}
      config = %{params: [:search], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["search"] == "hello world"
    end

    test "encodes template without prefix" do
      state = %{filter_values: %{}, template: :grid}
      config = %{params: [:template], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["template"] == "grid"
    end
  end

  describe "encode/2 with prefix" do
    test "encodes filters with prefix" do
      state = %{filter_values: %{status: "active", category: "news"}}
      config = %{params: [:filters], prefix: "sites"}

      result = UrlSync.encode(state, config)

      assert result["sites_filter_status"] == "active"
      assert result["sites_filter_category"] == "news"
    end

    test "encodes sort with prefix" do
      state = %{filter_values: %{}, sort_fields: [{:inserted_at, :desc}]}
      config = %{params: [:sort], prefix: "sites"}

      result = UrlSync.encode(state, config)

      assert result["sites_sort"] == "inserted_at:desc"
    end

    test "encodes page with prefix" do
      state = %{filter_values: %{}, page: 3}
      config = %{params: [:page], prefix: "posts"}

      result = UrlSync.encode(state, config)

      assert result["posts_page"] == "3"
    end

    test "encodes search with prefix" do
      state = %{filter_values: %{search: "test query"}}
      config = %{params: [:search], prefix: "users"}

      result = UrlSync.encode(state, config)

      assert result["users_search"] == "test query"
    end

    test "encodes template with prefix" do
      state = %{filter_values: %{}, template: :cards}
      config = %{params: [:template], prefix: "items"}

      result = UrlSync.encode(state, config)

      assert result["items_template"] == "cards"
    end

    test "encodes all params with prefix" do
      state = %{
        filter_values: %{status: "active", search: "hello"},
        sort_fields: [{:name, :asc}],
        page: 2,
        template: :grid
      }

      config = %{params: [:filters, :sort, :page, :search, :template], prefix: "t"}

      result = UrlSync.encode(state, config)

      assert result["t_filter_status"] == "active"
      assert result["t_sort"] == "name:asc"
      assert result["t_page"] == "2"
      assert result["t_search"] == "hello"
      assert result["t_template"] == "grid"
    end
  end

  describe "encode/2 respects params config" do
    test "only encodes params in config" do
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 5
      }

      config = %{params: [:filters], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["filter_status"] == "active"
      refute Map.has_key?(result, "sort")
      refute Map.has_key?(result, "page")
    end

    test "returns empty map when params is empty" do
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 5
      }

      config = %{params: [], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result == %{}
    end
  end

  describe "encode/2 with special values" do
    test "encodes list filter values as comma-separated" do
      state = %{filter_values: %{tags: ["elixir", "phoenix", "ash"]}}
      config = %{params: [:filters], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["filter_tags"] == "elixir,phoenix,ash"
    end

    test "encodes atom filter values as strings" do
      state = %{filter_values: %{status: :active}}
      config = %{params: [:filters], prefix: nil}

      result = UrlSync.encode(state, config)

      assert result["filter_status"] == "active"
    end

    test "skips nil filter values" do
      state = %{filter_values: %{status: nil, category: "news"}}
      config = %{params: [:filters], prefix: nil}

      result = UrlSync.encode(state, config)

      refute Map.has_key?(result, "filter_status")
      assert result["filter_category"] == "news"
    end

    test "skips empty string filter values" do
      state = %{filter_values: %{status: "", category: "news"}}
      config = %{params: [:filters], prefix: nil}

      result = UrlSync.encode(state, config)

      refute Map.has_key?(result, "filter_status")
      assert result["filter_category"] == "news"
    end

    test "skips empty sort list" do
      state = %{filter_values: %{}, sort_fields: []}
      config = %{params: [:sort], prefix: nil}

      result = UrlSync.encode(state, config)

      refute Map.has_key?(result, "sort")
    end
  end

  describe "decode/3 without prefix" do
    test "decodes filters without prefix" do
      params = %{
        "filter_status" => "active",
        "filter_category" => "news"
      }

      result = UrlSync.decode(params, "", allowed_params: [:filters])

      assert result.filters == %{status: "active", category: "news"}
    end

    test "decodes sort without prefix" do
      params = %{"sort" => "inserted_at:desc"}

      result = UrlSync.decode(params, "", allowed_params: [:sort])

      assert result.sort == [{:inserted_at, :desc}]
    end

    test "decodes multiple sort fields without prefix" do
      params = %{"sort" => "name:asc,inserted_at:desc"}

      result = UrlSync.decode(params, "", allowed_params: [:sort])

      assert result.sort == [{:name, :asc}, {:inserted_at, :desc}]
    end

    test "decodes page without prefix" do
      params = %{"page" => "5"}

      result = UrlSync.decode(params, "", allowed_params: [:page])

      assert result.page == 5
    end

    test "decodes search without prefix" do
      params = %{"search" => "hello world"}

      result = UrlSync.decode(params, "", allowed_params: [:search])

      assert result.search == "hello world"
    end

    test "decodes template without prefix" do
      params = %{"template" => "grid"}

      result = UrlSync.decode(params, "", allowed_params: [:template])

      assert result.template == :grid
    end
  end

  describe "decode/3 with prefix" do
    test "decodes filters with prefix" do
      params = %{
        "sites_filter_status" => "active",
        "sites_filter_category" => "news"
      }

      result = UrlSync.decode(params, "sites", allowed_params: [:filters])

      assert result.filters == %{status: "active", category: "news"}
    end

    test "decodes sort with prefix" do
      params = %{"sites_sort" => "inserted_at:desc"}

      result = UrlSync.decode(params, "sites", allowed_params: [:sort])

      assert result.sort == [{:inserted_at, :desc}]
    end

    test "decodes page with prefix" do
      params = %{"posts_page" => "3"}

      result = UrlSync.decode(params, "posts", allowed_params: [:page])

      assert result.page == 3
    end

    test "decodes search with prefix" do
      params = %{"users_search" => "test query"}

      result = UrlSync.decode(params, "users", allowed_params: [:search])

      assert result.search == "test query"
    end

    test "ignores params without matching prefix" do
      params = %{
        "sites_filter_status" => "active",
        "other_filter_category" => "news",
        "filter_tag" => "elixir"
      }

      result = UrlSync.decode(params, "sites", allowed_params: [:filters])

      assert result.filters == %{status: "active"}
      refute Map.has_key?(result.filters, :category)
      refute Map.has_key?(result.filters, :tag)
    end
  end

  describe "decode/3 with allowed_params" do
    test "only decodes params in allowed_params list" do
      params = %{
        "t_filter_status" => "active",
        "t_sort" => "name:asc",
        "t_page" => "5",
        "t_search" => "hello"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:filters, :page])

      assert result.filters == %{status: "active"}
      assert result.page == 5
      assert result.sort == []
      assert result.search == nil
    end

    test "returns defaults when param type not in allowed_params" do
      params = %{
        "t_filter_status" => "active",
        "t_sort" => "name:asc"
      }

      result = UrlSync.decode(params, "t", allowed_params: [])

      assert result.filters == %{}
      assert result.sort == []
      assert result.page == 1
      assert result.search == nil
      assert result.template == nil
    end

    test "decodes all params when allowed_params includes all types" do
      params = %{
        "t_filter_status" => "active",
        "t_sort" => "name:asc",
        "t_page" => "3",
        "t_search" => "test"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:filters, :sort, :page, :search])

      assert result.filters == %{status: "active"}
      assert result.sort == [{:name, :asc}]
      assert result.page == 3
      assert result.search == "test"
    end
  end

  describe "decode/3 with allowed_filters" do
    test "only decodes filters in allowed_filters list" do
      params = %{
        "t_filter_status" => "active",
        "t_filter_category" => "news",
        "t_filter_search" => "hello"
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          allowed_filters: [:status, :search]
        )

      assert result.filters == %{status: "active", search: "hello"}
      refute Map.has_key?(result.filters, :category)
    end

    test "ignores filters not in allowed_filters list" do
      params = %{
        "t_filter_hacker" => "malicious",
        "t_filter_status" => "active"
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          allowed_filters: [:status]
        )

      assert result.filters == %{status: "active"}
      refute Map.has_key?(result.filters, :hacker)
    end

    test "decodes all filters when allowed_filters is nil" do
      params = %{
        "t_filter_status" => "active",
        "t_filter_category" => "news"
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          allowed_filters: nil
        )

      assert result.filters == %{status: "active", category: "news"}
    end

    test "decodes all filters when allowed_filters is empty list" do
      params = %{
        "t_filter_status" => "active"
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          allowed_filters: []
        )

      assert result.filters == %{status: "active"}
    end
  end

  describe "decode/3 with max_filter_length" do
    test "ignores filter values exceeding max_filter_length" do
      long_value = String.duplicate("a", 600)

      params = %{
        "t_filter_status" => long_value,
        "t_filter_category" => "short"
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          max_filter_length: 500
        )

      refute Map.has_key?(result.filters, :status)
      assert result.filters == %{category: "short"}
    end

    test "accepts filter values within max_filter_length" do
      value = String.duplicate("a", 500)

      params = %{
        "t_filter_status" => value
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          max_filter_length: 500
        )

      assert result.filters == %{status: value}
    end

    test "uses default max_filter_length of 500 when not specified" do
      long_value = String.duplicate("a", 501)

      params = %{
        "t_filter_status" => long_value
      }

      result = UrlSync.decode(params, "t", allowed_params: [:filters])

      refute Map.has_key?(result.filters, :status)
    end

    test "allows custom max_filter_length" do
      value = String.duplicate("a", 100)

      params = %{
        "t_filter_status" => value
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters],
          max_filter_length: 50
        )

      refute Map.has_key?(result.filters, :status)
    end
  end

  describe "decode/3 combined options" do
    test "respects all options together" do
      long_value = String.duplicate("x", 600)

      params = %{
        "t_filter_status" => "active",
        "t_filter_hacker" => "bad",
        "t_filter_long" => long_value,
        "t_sort" => "name:asc",
        "t_page" => "10"
      }

      result =
        UrlSync.decode(params, "t",
          allowed_params: [:filters, :page],
          allowed_filters: [:status, :long],
          max_filter_length: 500
        )

      assert result.filters == %{status: "active"}
      refute Map.has_key?(result.filters, :hacker)
      refute Map.has_key?(result.filters, :long)
      assert result.sort == []
      assert result.page == 10
    end
  end

  describe "decode/3 security" do
    test "ignores non-existing atoms in filter names" do
      params = %{
        "t_filter_this_atom_does_not_exist_12345" => "value"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:filters])

      assert result.filters == %{}
    end

    test "handles malformed sort values gracefully" do
      params = %{
        "t_sort" => "invalid::format:::here"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:sort])

      assert result.sort == []
    end

    test "handles malformed page values gracefully" do
      params = %{
        "t_page" => "not_a_number"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:page])

      assert result.page == 1
    end

    test "handles non-existing atom in template gracefully" do
      params = %{
        "t_template" => "this_template_does_not_exist_xyz"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:template])

      assert result.template == nil
    end

    test "handles non-existing atom in sort field gracefully" do
      params = %{
        "t_sort" => "nonexistent_field_xyz:asc"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:sort])

      assert result.sort == []
    end
  end

  describe "decode/3 with comma-separated values" do
    test "decodes comma-separated filter values as list" do
      params = %{
        "t_filter_tags" => "elixir,phoenix,ash"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:filters])

      assert result.filters == %{tags: ["elixir", "phoenix", "ash"]}
    end

    test "decodes single value without comma as string" do
      params = %{
        "t_filter_status" => "active"
      }

      result = UrlSync.decode(params, "t", allowed_params: [:filters])

      assert result.filters == %{status: "active"}
    end
  end

  describe "apply_url_state/2" do
    test "applies filters to state" do
      state = %{filter_values: %{}, sort_fields: [], page: 1}
      url_state = %{filters: %{status: "active"}, sort: [], page: 1, search: nil, template: nil}

      result = UrlSync.apply_url_state(state, url_state)

      assert result.filter_values == %{status: "active"}
    end

    test "merges filters with existing state" do
      state = %{filter_values: %{category: "news"}, sort_fields: [], page: 1}
      url_state = %{filters: %{status: "active"}, sort: [], page: 1, search: nil, template: nil}

      result = UrlSync.apply_url_state(state, url_state)

      assert result.filter_values == %{category: "news", status: "active"}
    end

    test "applies sort to state" do
      state = %{filter_values: %{}, sort_fields: [], page: 1, relation_filter_state: %{}}
      url_state = %{filters: %{}, sort: [{:name, :asc}], page: 1, search: nil, template: nil}

      result = UrlSync.apply_url_state(state, url_state)

      assert result.sort_fields == [{:name, :asc}]
    end

    test "applies page to state when > 1" do
      state = %{filter_values: %{}, sort_fields: [], page: 1, relation_filter_state: %{}}
      url_state = %{filters: %{}, sort: [], page: 5, search: nil, template: nil}

      result = UrlSync.apply_url_state(state, url_state)

      assert result.page == 5
    end

    test "does not apply page 1 to state" do
      state = %{filter_values: %{}, sort_fields: [], page: 3, relation_filter_state: %{}}
      url_state = %{filters: %{}, sort: [], page: 1, search: nil, template: nil}

      result = UrlSync.apply_url_state(state, url_state)

      assert result.page == 3
    end

    test "applies search to filter_values" do
      state = %{filter_values: %{}, sort_fields: [], page: 1, relation_filter_state: %{}}
      url_state = %{filters: %{}, sort: [], page: 1, search: "hello", template: nil}

      result = UrlSync.apply_url_state(state, url_state)

      assert result.filter_values == %{search: "hello"}
    end

    test "applies all url_state fields" do
      state = %{filter_values: %{}, sort_fields: [], page: 1}

      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :desc}],
        page: 3,
        search: "test",
        template: :grid
      }

      result = UrlSync.apply_url_state(state, url_state)

      assert result.filter_values == %{status: "active", search: "test"}
      assert result.sort_fields == [{:name, :desc}]
      assert result.page == 3
    end
  end

  describe "enabled?/1" do
    test "returns true when enabled is true" do
      config = %{enabled: true}
      assert UrlSync.enabled?(config) == true
    end

    test "returns false when enabled is false" do
      config = %{enabled: false}
      assert UrlSync.enabled?(config) == false
    end

    test "returns false when enabled is not present" do
      config = %{}
      assert UrlSync.enabled?(config) == false
    end
  end

  describe "build_path/3" do
    test "builds path with encoded params without prefix" do
      state = %{filter_values: %{status: "active"}, sort_fields: [{:name, :asc}], page: 2}
      config = %{params: [:filters, :sort, :page], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result =~ "/admin/posts?"
      assert result =~ "filter_status=active"
      assert result =~ "sort=name%3Aasc"
      assert result =~ "page=2"
    end

    test "builds path with encoded params with prefix" do
      state = %{filter_values: %{status: "active"}, sort_fields: [{:name, :asc}], page: 2}
      config = %{params: [:filters, :sort, :page], prefix: "sites"}

      result = UrlSync.build_path("/admin/sites", state, config)

      assert result =~ "/admin/sites?"
      assert result =~ "sites_filter_status=active"
      assert result =~ "sites_sort=name%3Aasc"
      assert result =~ "sites_page=2"
    end

    test "returns base path when no params to encode" do
      state = %{filter_values: %{}, sort_fields: [], page: 1}
      config = %{params: [:filters, :sort, :page], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result == "/admin/posts"
    end

    test "returns base path when params config is empty" do
      state = %{filter_values: %{status: "active"}, sort_fields: [{:name, :asc}], page: 2}
      config = %{params: [], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result == "/admin/posts"
    end
  end

  describe "matches_state?/2" do
    test "returns true when url_state matches state" do
      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :asc}],
        page: 2
      }

      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 2
      }

      assert UrlSync.matches_state?(url_state, state) == true
    end

    test "returns false when filters don't match" do
      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :asc}],
        page: 2
      }

      state = %{
        filter_values: %{status: "inactive"},
        sort_fields: [{:name, :asc}],
        page: 2
      }

      assert UrlSync.matches_state?(url_state, state) == false
    end

    test "returns false when sort doesn't match" do
      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :asc}],
        page: 2
      }

      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :desc}],
        page: 2
      }

      assert UrlSync.matches_state?(url_state, state) == false
    end

    test "returns false when page doesn't match" do
      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :asc}],
        page: 2
      }

      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 3
      }

      assert UrlSync.matches_state?(url_state, state) == false
    end

    test "returns false when url_state is nil" do
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 2
      }

      assert UrlSync.matches_state?(nil, state) == false
    end
  end

  describe "roundtrip encode/decode without prefix" do
    test "encodes and decodes filters correctly" do
      original_state = %{filter_values: %{status: "active", category: "news"}}
      config = %{params: [:filters], prefix: nil}

      encoded = UrlSync.encode(original_state, config)
      decoded = UrlSync.decode(encoded, "", allowed_params: [:filters])

      assert decoded.filters == %{status: "active", category: "news"}
    end

    test "encodes and decodes sort correctly" do
      original_state = %{filter_values: %{}, sort_fields: [{:name, :asc}, {:inserted_at, :desc}]}
      config = %{params: [:sort], prefix: nil}

      encoded = UrlSync.encode(original_state, config)
      decoded = UrlSync.decode(encoded, "", allowed_params: [:sort])

      assert decoded.sort == [{:name, :asc}, {:inserted_at, :desc}]
    end

    test "encodes and decodes page correctly" do
      original_state = %{filter_values: %{}, page: 5}
      config = %{params: [:page], prefix: nil}

      encoded = UrlSync.encode(original_state, config)
      decoded = UrlSync.decode(encoded, "", allowed_params: [:page])

      assert decoded.page == 5
    end

    test "encodes and decodes all params correctly" do
      original_state = %{
        filter_values: %{status: "active", search: "hello"},
        sort_fields: [{:name, :asc}],
        page: 3,
        template: :grid
      }

      config = %{params: [:filters, :sort, :page, :search, :template], prefix: nil}

      encoded = UrlSync.encode(original_state, config)

      decoded =
        UrlSync.decode(encoded, "", allowed_params: [:filters, :sort, :page, :search, :template])

      # search is in filter_values, so it's encoded both as filter_search AND search param
      assert decoded.filters == %{status: "active", search: "hello"}
      assert decoded.sort == [{:name, :asc}]
      assert decoded.page == 3
      assert decoded.search == "hello"
      assert decoded.template == :grid
    end
  end

  describe "roundtrip encode/decode with prefix" do
    test "encodes and decodes filters correctly with prefix" do
      original_state = %{filter_values: %{status: "active", category: "news"}}
      config = %{params: [:filters], prefix: "sites"}

      encoded = UrlSync.encode(original_state, config)
      decoded = UrlSync.decode(encoded, "sites", allowed_params: [:filters])

      assert decoded.filters == %{status: "active", category: "news"}
    end

    test "encodes and decodes sort correctly with prefix" do
      original_state = %{filter_values: %{}, sort_fields: [{:inserted_at, :desc}]}
      config = %{params: [:sort], prefix: "posts"}

      encoded = UrlSync.encode(original_state, config)
      decoded = UrlSync.decode(encoded, "posts", allowed_params: [:sort])

      assert decoded.sort == [{:inserted_at, :desc}]
    end

    test "encodes and decodes all params correctly with prefix" do
      original_state = %{
        filter_values: %{status: "active", search: "test"},
        sort_fields: [{:name, :desc}],
        page: 7,
        template: :cards
      }

      config = %{params: [:filters, :sort, :page, :search, :template], prefix: "items"}

      encoded = UrlSync.encode(original_state, config)

      decoded =
        UrlSync.decode(encoded, "items",
          allowed_params: [:filters, :sort, :page, :search, :template]
        )

      # search is in filter_values, so it's encoded both as filter_search AND search param
      assert decoded.filters == %{status: "active", search: "test"}
      assert decoded.sort == [{:name, :desc}]
      assert decoded.page == 7
      assert decoded.search == "test"
      assert decoded.template == :cards
    end
  end

  describe "path_params in matches_state?/2" do
    test "returns true when path_params match" do
      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :asc}],
        page: 2,
        path_params: %{workspace_version_id: "abc-123"}
      }

      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 2,
        path_params: %{workspace_version_id: "abc-123"}
      }

      assert UrlSync.matches_state?(url_state, state) == true
    end

    test "returns false when path_params don't match" do
      url_state = %{
        filters: %{status: "active"},
        sort: [{:name, :asc}],
        page: 2,
        path_params: %{workspace_version_id: "abc-123"}
      }

      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 2,
        path_params: %{workspace_version_id: "def-456"}
      }

      assert UrlSync.matches_state?(url_state, state) == false
    end

    test "returns true when both path_params are empty" do
      url_state = %{
        filters: %{},
        sort: [],
        page: 1,
        path_params: %{}
      }

      state = %{
        filter_values: %{},
        sort_fields: [],
        page: 1,
        path_params: %{}
      }

      assert UrlSync.matches_state?(url_state, state) == true
    end

    test "defaults missing path_params to empty map" do
      url_state = %{
        filters: %{},
        sort: [],
        page: 1,
        path_params: %{}
      }

      # State without path_params key (backward compat)
      state = %{
        filter_values: %{},
        sort_fields: [],
        page: 1
      }

      assert UrlSync.matches_state?(url_state, state) == true
    end
  end

  describe "path_params in decode" do
    test "decode/3 returns empty path_params for legacy prefix-based decode" do
      params = %{"filter_status" => "active"}
      result = UrlSync.decode(params, "", allowed_params: [:filters])

      assert result.path_params == %{}
    end
  end

  describe "real-world URL scenarios" do
    test "sites table with prefix" do
      params = %{
        "sites_sort" => "inserted_at:desc",
        "sites_page" => "2",
        "sites_filter_status" => "active"
      }

      result =
        UrlSync.decode(params, "sites", allowed_params: [:filters, :sort, :page])

      assert result.filters == %{status: "active"}
      assert result.sort == [{:inserted_at, :desc}]
      assert result.page == 2
    end

    test "posts table without prefix" do
      params = %{
        "sort" => "inserted_at:desc",
        "page" => "3",
        "filter_status" => "published"
      }

      result =
        UrlSync.decode(params, "", allowed_params: [:filters, :sort, :page])

      assert result.filters == %{status: "published"}
      assert result.sort == [{:inserted_at, :desc}]
      assert result.page == 3
    end

    test "multiple tables on same page with different prefixes" do
      params = %{
        "posts_sort" => "title:asc",
        "posts_page" => "2",
        "users_sort" => "name:desc",
        "users_page" => "5",
        "comments_filter_approved" => "true"
      }

      posts_result =
        UrlSync.decode(params, "posts", allowed_params: [:sort, :page])

      users_result =
        UrlSync.decode(params, "users", allowed_params: [:sort, :page])

      comments_result =
        UrlSync.decode(params, "comments", allowed_params: [:filters])

      assert posts_result.sort == [{:title, :asc}]
      assert posts_result.page == 2

      assert users_result.sort == [{:name, :desc}]
      assert users_result.page == 5

      assert comments_result.filters == %{approved: "true"}
    end
  end

  # ===================================================================
  # preserve_params tests
  # ===================================================================

  describe "build_path/3 with preserved_params" do
    test "merges preserved_params into URL" do
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [],
        page: 1,
        preserved_params: %{"return_to" => "abc-123"}
      }

      config = %{params: [:filters], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result =~ "filter_status=active"
      assert result =~ "return_to=abc-123"
    end

    test "merges multiple preserved_params into URL" do
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [],
        page: 1,
        preserved_params: %{"return_to" => "abc-123", "ref" => "dashboard"}
      }

      config = %{params: [:filters], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result =~ "filter_status=active"
      assert result =~ "return_to=abc-123"
      assert result =~ "ref=dashboard"
    end

    test "preserved_params appear even with no table params" do
      state = %{
        filter_values: %{},
        sort_fields: [],
        page: 1,
        preserved_params: %{"return_to" => "abc-123"}
      }

      config = %{params: [:filters, :sort, :page], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result == "/admin/posts?return_to=abc-123"
    end

    test "returns base path when no table params and no preserved_params" do
      state = %{
        filter_values: %{},
        sort_fields: [],
        page: 1,
        preserved_params: %{}
      }

      config = %{params: [:filters, :sort, :page], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result == "/admin/posts"
    end

    test "handles nil preserved_params in state" do
      state = %{
        filter_values: %{},
        sort_fields: [],
        page: 1
      }

      config = %{params: [:filters, :sort, :page], prefix: nil}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result == "/admin/posts"
    end

    test "preserved_params with prefix do not collide with table params" do
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [{:name, :asc}],
        page: 2,
        preserved_params: %{"return_to" => "uuid-value"}
      }

      config = %{params: [:filters, :sort, :page], prefix: "t"}

      result = UrlSync.build_path("/admin/posts", state, config)

      assert result =~ "t_filter_status=active"
      assert result =~ "t_sort=name"
      assert result =~ "t_page=2"
      assert result =~ "return_to=uuid-value"
    end
  end

  describe "decode/4 with preserve_params via resource (specific list)" do
    alias MishkaGervaz.Test.Resources.Post

    test "extracts specified preserve_params from URL params" do
      params = %{
        "filter_status" => "active",
        "return_to" => "some-uuid-value"
      }

      result = UrlSync.decode(params, "/posts", Post)

      assert result.filters == %{status: "active"}
      assert result.preserved_params == %{"return_to" => "some-uuid-value"}
    end

    test "ignores non-specified params when using specific list" do
      params = %{
        "filter_status" => "active",
        "return_to" => "some-uuid",
        "utm_source" => "google"
      }

      result = UrlSync.decode(params, "/posts", Post)

      assert result.preserved_params == %{"return_to" => "some-uuid"}
      refute Map.has_key?(result.preserved_params, "utm_source")
    end

    test "returns empty preserved_params when param not present in URL" do
      params = %{"filter_status" => "active"}

      result = UrlSync.decode(params, "/posts", Post)

      assert result.preserved_params == %{}
    end

    test "applies max_filter_length to preserved param values" do
      long_value = String.duplicate("a", 501)

      params = %{
        "return_to" => long_value
      }

      result = UrlSync.decode(params, "/posts", Post)

      assert result.preserved_params == %{}
    end

    test "accepts preserved param values within max_filter_length" do
      value = String.duplicate("a", 500)

      params = %{
        "return_to" => value
      }

      result = UrlSync.decode(params, "/posts", Post)

      assert result.preserved_params == %{"return_to" => value}
    end
  end

  describe "decode/4 with preserve_params :all via resource" do
    alias MishkaGervaz.Test.Resources.ComplexTestResource

    test "preserves all unknown params" do
      params = %{
        "posts_filter_status" => "active",
        "posts_sort" => "name:asc",
        "return_to" => "some-uuid",
        "utm_source" => "google"
      }

      result = UrlSync.decode(params, "/posts", ComplexTestResource)

      assert result.filters == %{status: "active"}
      assert result.sort == [{:name, :asc}]
      assert result.preserved_params["return_to"] == "some-uuid"
      assert result.preserved_params["utm_source"] == "google"
    end

    test "does not preserve known prefixed params" do
      params = %{
        "posts_filter_status" => "active",
        "posts_sort" => "name:asc",
        "posts_page" => "2",
        "posts_search" => "hello",
        "custom_param" => "keep-me"
      }

      result = UrlSync.decode(params, "/posts", ComplexTestResource)

      refute Map.has_key?(result.preserved_params, "posts_filter_status")
      refute Map.has_key?(result.preserved_params, "posts_sort")
      refute Map.has_key?(result.preserved_params, "posts_page")
      refute Map.has_key?(result.preserved_params, "posts_search")
      assert result.preserved_params["custom_param"] == "keep-me"
    end

    test "returns empty preserved_params when all params are known" do
      params = %{
        "posts_filter_status" => "active",
        "posts_sort" => "name:asc"
      }

      result = UrlSync.decode(params, "/posts", ComplexTestResource)

      assert result.preserved_params == %{}
    end

    test "applies max_filter_length to preserved params in :all mode" do
      long_value = String.duplicate("x", 501)

      params = %{
        "custom_param" => long_value,
        "short_param" => "ok"
      }

      result = UrlSync.decode(params, "/posts", ComplexTestResource)

      refute Map.has_key?(result.preserved_params, "custom_param")
      assert result.preserved_params["short_param"] == "ok"
    end
  end

  describe "preserve_params roundtrip" do
    alias MishkaGervaz.Test.Resources.Post

    test "preserved params survive encode-decode roundtrip via build_path" do
      # Simulate: decode from URL, then re-encode for push_patch
      params = %{
        "filter_status" => "active",
        "return_to" => "abc-123"
      }

      url_state = UrlSync.decode(params, "/posts", Post)

      # Simulate state that would exist after apply_url_state
      state = %{
        filter_values: %{status: "active"},
        sort_fields: [],
        page: 1,
        preserved_params: url_state.preserved_params
      }

      config = %{params: [:filters, :sort, :page, :search], prefix: nil}

      new_path = UrlSync.build_path("/posts", state, config)

      assert new_path =~ "filter_status=active"
      assert new_path =~ "return_to=abc-123"
    end

    test "preserved params persist when filters change" do
      # First decode with return_to
      params = %{
        "filter_status" => "active",
        "return_to" => "abc-123"
      }

      url_state = UrlSync.decode(params, "/posts", Post)

      # User changes filter — state updates but preserved_params stays
      state = %{
        filter_values: %{status: "inactive"},
        sort_fields: [{:name, :desc}],
        page: 3,
        preserved_params: url_state.preserved_params
      }

      config = %{params: [:filters, :sort, :page], prefix: nil}

      new_path = UrlSync.build_path("/posts", state, config)

      assert new_path =~ "filter_status=inactive"
      assert new_path =~ "sort=name"
      assert new_path =~ "page=3"
      assert new_path =~ "return_to=abc-123"
    end
  end
end

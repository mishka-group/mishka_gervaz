defmodule MishkaGervaz.Table.Web.DataLoader.QueryBuilderPathParamsTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Table.Web.DataLoader.QueryBuilder.apply_path_params/3`.

  Each path param naming an attribute scopes the read, and the value decides the operator:

  | value | attribute | filter |
  | --- | --- | --- |
  | `nil` | any | `is_nil(attribute)` |
  | a list | scalar | `attribute in list` |
  | a list | `{:array, _}` | `attribute == list` |
  | anything else | any | `attribute == value` |

  A param naming no attribute is skipped. Every rule is proven twice: on the filter the query
  carries, and on the rows an ETS read returns.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.DataLoader.QueryBuilder.Default, as: QueryBuilder
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.DataLoader.{FilterableResource, SortableResource}
  alias MishkaGervaz.Test.Resources.StringListForm

  @resources [FilterableResource, SortableResource, StringListForm]

  setup do
    Enum.each(@resources, &clear_ets/1)
    on_exit(fn -> Enum.each(@resources, &clear_ets/1) end)
    :ok
  end

  describe "a list on a scalar attribute" do
    setup :categories

    test "reads only the rows whose value is one of the list", %{rows: rows} do
      assert read_ids(FilterableResource, %{category: ["tech", "news"]}) ==
               ids(rows, [:tech, :news])
    end

    test "is filtered with in, not ==" do
      filter = filter_of(FilterableResource, %{category: ["tech", "news"]})

      assert filter =~ "category in"
      refute filter =~ "=="
    end

    test "of one item reads the same rows as the bare value", %{rows: rows} do
      assert read_ids(FilterableResource, %{category: ["tech"]}) == ids(rows, [:tech])
      assert read_ids(FilterableResource, %{category: "tech"}) == ids(rows, [:tech])
    end

    test "never reads a null row, even beside other values", %{rows: rows} do
      read = read_ids(FilterableResource, %{category: ["tech", "news", "sports"]})

      assert read == ids(rows, [:tech, :news, :sports])
      refute MapSet.member?(read, rows.none.id)
    end

    test "that is empty reads no rows" do
      assert read_ids(FilterableResource, %{category: []}) == MapSet.new()
    end

    test "of values no row holds reads no rows" do
      assert read_ids(FilterableResource, %{category: ["missing-#{unique()}"]}) == MapSet.new()
    end

    test "on an integer attribute reads the rows holding any of the integers" do
      one = Ash.create!(SortableResource, %{name: "one-#{unique()}", score: 1})
      _two = Ash.create!(SortableResource, %{name: "two-#{unique()}", score: 2})
      three = Ash.create!(SortableResource, %{name: "three-#{unique()}", score: 3})

      assert read_ids(SortableResource, %{score: [1, 3]}) == MapSet.new([one.id, three.id])
    end
  end

  describe "a list on an array attribute" do
    setup :tag_lists

    test "means the whole array, so only the exact array is read", %{rows: rows} do
      assert read_ids(StringListForm, %{tags: ["a", "b"]}) == ids(rows, [:ab])
    end

    test "does not match an array holding the same items in another order", %{rows: rows} do
      refute MapSet.member?(read_ids(StringListForm, %{tags: ["a", "b"]}), rows.ba.id)
    end

    test "does not match an array holding only some of them, or more", %{rows: rows} do
      read = read_ids(StringListForm, %{tags: ["a", "b"]})

      refute MapSet.member?(read, rows.a.id)
      refute MapSet.member?(read, rows.abc.id)
    end

    test "is filtered with ==, not in" do
      filter = filter_of(StringListForm, %{tags: ["a", "b"]})

      assert filter =~ "=="
      refute filter =~ "tags in"
    end

    test "that is empty reads the rows whose array is empty", %{rows: rows} do
      assert read_ids(StringListForm, %{tags: []}) == ids(rows, [:empty])
    end
  end

  describe "a nil value" do
    test "on a scalar attribute reads the rows where the column is null" do
      %{rows: rows} = categories(%{})

      assert read_ids(FilterableResource, %{category: nil}) == ids(rows, [:none])
      assert filter_of(FilterableResource, %{category: nil}) =~ "is_nil"
    end

    test "on an array attribute reads the null row, not the empty one" do
      %{rows: rows} = tag_lists(%{})

      assert read_ids(StringListForm, %{tags: nil}) == ids(rows, [:null])
      assert filter_of(StringListForm, %{tags: nil}) =~ "is_nil"
    end

    test "is never compared with ==" do
      refute filter_of(FilterableResource, %{category: nil}) =~ "=="
      refute filter_of(StringListForm, %{tags: nil}) =~ "=="
    end
  end

  describe "a param naming no attribute" do
    setup :categories

    test "leaves the query as it was" do
      query = Ash.Query.new(FilterableResource)

      assert QueryBuilder.apply_path_params(query, %{revision: ["tech"]}, FilterableResource) ==
               query
    end

    test "reads every row" do
      assert read_ids(FilterableResource, %{revision: 3, token_format: :tw}) ==
               read_ids(FilterableResource, %{})
    end

    test "is skipped while the params beside it still filter", %{rows: rows} do
      params = %{category: ["tech", "news"], revision: 3, editing_draft_id: nil}

      assert read_ids(FilterableResource, params) == ids(rows, [:tech, :news])
    end

    test "is matched by atom name only, so a string key filters nothing" do
      query = Ash.Query.new(FilterableResource)

      assert QueryBuilder.apply_path_params(query, %{"category" => "tech"}, FilterableResource) ==
               query
    end
  end

  describe "several params" do
    setup :categories

    test "must all hold for a row to be read", %{rows: rows} do
      params = %{category: ["tech", "news", "sports"], status: "published"}

      assert read_ids(FilterableResource, params) == ids(rows, [:tech, :sports])
    end

    test "combine a list, a nil and a bare value in one read", %{rows: rows} do
      params = %{category: nil, status: ["draft", "archived"], title: rows.none.title}

      assert read_ids(FilterableResource, params) == ids(rows, [:none])
    end
  end

  describe "an empty map" do
    test "leaves the query as it was" do
      query = Ash.Query.new(FilterableResource)

      assert QueryBuilder.apply_path_params(query, %{}, FilterableResource) == query
    end
  end

  describe "build_query/1" do
    setup :categories

    test "scopes the table's read by a list path param", %{rows: rows} do
      state = %{
        State.init("path-params-#{unique()}", FilterableResource, master_user())
        | path_params: %{category: ["tech", "news"]}
      }

      read =
        state
        |> QueryBuilder.build_query()
        |> Ash.read!(read_opts(FilterableResource))
        |> records()
        |> MapSet.new(& &1.id)

      assert read == ids(rows, [:tech, :news])
    end
  end

  defp categories(_context) do
    rows = %{
      tech: create_filterable("tech", "published"),
      news: create_filterable("news", "draft"),
      sports: create_filterable("sports", "published"),
      none: create_filterable(nil, "draft")
    }

    %{rows: rows}
  end

  defp tag_lists(_context) do
    rows = %{
      ab: create_tagged(["a", "b"]),
      ba: create_tagged(["b", "a"]),
      a: create_tagged(["a"]),
      abc: create_tagged(["a", "b", "c"]),
      empty: create_tagged([]),
      null: create_tagged(nil)
    }

    %{rows: rows}
  end

  defp create_filterable(category, status) do
    Ash.create!(FilterableResource, %{
      title: "row-#{unique()}",
      category: category,
      status: status
    })
  end

  defp create_tagged(tags) do
    Ash.create!(StringListForm, %{title: "row-#{unique()}", tags: tags})
  end

  defp read_ids(resource, path_params) do
    resource
    |> Ash.Query.new()
    |> QueryBuilder.apply_path_params(path_params, resource)
    |> Ash.read!(read_opts(resource))
    |> records()
    |> MapSet.new(& &1.id)
  end

  defp read_opts(resource) do
    case Ash.Resource.Info.primary_action!(resource, :read).pagination do
      false -> []
      _pagination -> [page: [offset: 0, limit: 100]]
    end
  end

  defp records(%{results: results}), do: results
  defp records(records) when is_list(records), do: records

  defp filter_of(resource, path_params) do
    resource
    |> Ash.Query.new()
    |> QueryBuilder.apply_path_params(path_params, resource)
    |> Map.fetch!(:filter)
    |> inspect()
  end

  defp ids(rows, keys), do: MapSet.new(keys, &Map.fetch!(rows, &1).id)

  defp master_user, do: %{id: "master-#{unique()}", site_id: nil, role: :admin}

  defp unique, do: System.unique_integer([:positive])

  defp clear_ets(resource) do
    MishkaGervaz.Test.Ets.stop(resource)
  rescue
    _ -> :ok
  end
end

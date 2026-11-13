defmodule MishkaGervaz.Types.Filter.RelationTest do
  @moduledoc """
  Tests for the Relation filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Relation
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Relation.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Relation.parse_value("", %{}) == nil
    end

    test "returns :nil_value for __nil__ string" do
      assert Relation.parse_value("__nil__", %{}) == :nil_value
    end

    test "returns value as-is for UUID string" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert Relation.parse_value(uuid, %{}) == uuid
    end

    test "returns value as-is for any other string" do
      assert Relation.parse_value("some_id", %{}) == "some_id"
    end
  end

  describe "build_query/3" do
    test "applies is_nil filter for :nil_value" do
      query = Ash.Query.new(Post)
      result = Relation.build_query(query, :user_id, :nil_value)
      assert result != query
    end

    test "applies eq filter for normal value" do
      query = Ash.Query.new(Post)
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      result = Relation.build_query(query, :user_id, uuid)
      assert result != query
    end

    test "returns query unchanged for nil" do
      query = Ash.Query.new(Post)
      result = Relation.build_query(query, :user_id, nil)
      assert result == query
    end

    test "returns query unchanged for empty string" do
      query = Ash.Query.new(Post)
      result = Relation.build_query(query, :user_id, "")
      assert result == query
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Relation.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end

  describe "render_input/3 on a live page" do
    defp tracked(%Phoenix.LiveView.Rendered{static: static, dynamic: dynamic}) do
      parts = Enum.map(dynamic.(true), &tracked/1)

      static
      |> Enum.zip(parts ++ [""])
      |> Enum.map_join(fn {text, part} -> text <> part end)
    end

    defp tracked(%Phoenix.LiveView.Comprehension{} = comprehension),
      do: comprehension |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    defp tracked(nil), do: ""
    defp tracked(text) when is_binary(text), do: text
    defp tracked(iodata) when is_list(iodata), do: IO.iodata_to_binary(iodata)
    defp tracked(other), do: other |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    # A live page diffs the select against the one it drew last, reading each part through change
    # tracking; a part read as unchanged would keep the shut select's attributes on the open one.
    test "draws every part again, so the open select says it is open" do
      filter = %{
        name: :site_id,
        mode: :search_multi,
        options: [{"North", "1"}],
        dropdown_open?: true,
        table_id: "pages",
        ui: %{}
      }

      html = filter |> Relation.render_input("", MishkaGervaz.UIAdapters.Tailwind) |> tracked()

      assert html =~ ~s(aria-expanded="true")
      assert html =~ "gervaz-relation-list"
      refute html =~ "phx-debounce"
    end
  end
end

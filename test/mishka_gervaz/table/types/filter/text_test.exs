defmodule MishkaGervaz.Types.Filter.TextTest do
  @moduledoc """
  Tests for the Text filter type.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Filter.Text
  alias MishkaGervaz.Test.Resources.Post

  describe "parse_value/2" do
    test "returns nil for nil value" do
      assert Text.parse_value(nil, %{}) == nil
    end

    test "returns nil for empty string" do
      assert Text.parse_value("", %{}) == nil
    end

    test "returns trimmed string for string value" do
      assert Text.parse_value("  hello  ", %{}) == "hello"
    end

    test "returns value as-is for other types" do
      assert Text.parse_value(123, %{}) == 123
    end
  end

  describe "build_query/3 single field" do
    test "returns query unchanged for nil value" do
      query = Ash.Query.new(Post)
      result = Text.build_query(query, :title, nil)
      assert result == query
    end

    test "returns query unchanged for empty string" do
      query = Ash.Query.new(Post)
      result = Text.build_query(query, :title, "")
      assert result == query
    end

    test "applies contains filter for string value" do
      query = Ash.Query.new(Post)
      result = Text.build_query(query, :title, "hello")
      assert result != query
    end
  end

  describe "build_query/4 multi-field" do
    test "applies OR filter across multiple fields" do
      query = Ash.Query.new(Post)
      filter = %{fields: [:title, :content]}
      result = Text.build_query(query, :search, "test", filter)
      assert result != query
    end

    test "falls back to single-field search for empty fields list" do
      query = Ash.Query.new(Post)
      filter = %{fields: []}
      result = Text.build_query(query, :search, "test", filter)
      # With empty fields, falls through to single-field build_query which applies filter
      assert result != query
    end

    test "returns query unchanged for nil value with fields" do
      query = Ash.Query.new(Post)
      filter = %{fields: [:title, :content]}
      result = Text.build_query(query, :search, nil, filter)
      assert result == query
    end
  end

  # READ BACK, NOT ONLY BUILT: the term is matched without case, and a LIKE wildcard in it is a
  # character like any other. The ETS data layer here, AshPostgres's escaped ILIKE in production.
  describe "what a search finds" do
    alias MishkaGervaz.Test.Resources.ComplexTestResource, as: Row

    setup do
      Ash.DataLayer.Ets.stop(Row)
      on_exit(fn -> Ash.DataLayer.Ets.stop(Row) end)

      for {title, content} <- [
            {"Contact us", "Reach the team"},
            {"contact form", nil},
            {"Other", "Contact the owner"},
            {"100% sure", nil},
            {"Snake_case", nil}
          ],
          do: Ash.create!(Row, %{title: title, content: content})

      :ok
    end

    defp titles(query), do: query |> Ash.read!() |> Enum.map(& &1.title) |> Enum.sort()

    test "a lowercase term finds a capitalized title" do
      assert Row |> Ash.Query.new() |> Text.build_query(:title, "contact") |> titles() ==
               ["Contact us", "contact form"]
    end

    test "an uppercase term finds a lowercase title" do
      assert Row |> Ash.Query.new() |> Text.build_query(:title, "CONTACT FORM") |> titles() ==
               ["contact form"]
    end

    test "across fields, a match in any of them, whatever its case" do
      found =
        Row
        |> Ash.Query.new()
        |> Text.build_query(:search, "CONTACT", %{fields: [:title, :content]})
        |> titles()

      assert found == ["Contact us", "Other", "contact form"]
    end

    test "a % or _ in the term is that character, not a wildcard" do
      assert Row |> Ash.Query.new() |> Text.build_query(:title, "0%") |> titles() == ["100% sure"]
      assert Row |> Ash.Query.new() |> Text.build_query(:title, "_") |> titles() == ["Snake_case"]
    end
  end

  describe "behaviour implementation" do
    test "implements FilterType behaviour" do
      behaviours = Text.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.FilterType in behaviours
    end
  end
end

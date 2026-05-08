defmodule MishkaGervaz.Form.Web.State.FieldBuilderTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.State.FieldBuilder.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.FieldBuilder.Default, as: FieldBuilder
  alias MishkaGervaz.Resource.Info.Form, as: Info
  alias MishkaGervaz.Test.Resources.FormPost

  describe "build/2" do
    test "returns a list of field config maps for a real resource" do
      config = Info.config(FormPost)
      result = FieldBuilder.build(config, FormPost)

      assert is_list(result)
      assert length(result) > 0

      for field <- result do
        assert is_map(field)
        assert Map.has_key?(field, :name)
        assert Map.has_key?(field, :resolved_label)
        assert Map.has_key?(field, :resolved_type)
        assert Map.has_key?(field, :attribute)
      end
    end

    test "returns [] for non-map config" do
      assert FieldBuilder.build(nil, FormPost) == []
      assert FieldBuilder.build(:atom, FormPost) == []
    end

    test "preserves DSL ordering when no field_order set" do
      config = Info.config(FormPost)
      result = FieldBuilder.build(config, FormPost)
      dsl_names = Enum.map(Info.fields(FormPost), & &1.name)

      assert Enum.map(result, & &1.name) == dsl_names
    end
  end

  describe "resolve_type/2" do
    test "returns field's :type when set" do
      assert FieldBuilder.resolve_type(%{type: :textarea}, %{}) == :textarea
      assert FieldBuilder.resolve_type(%{type: :relation}, %{}) == :relation
    end

    test "defaults to :text when :type is nil/missing" do
      assert FieldBuilder.resolve_type(%{type: nil}, %{}) == :text
      assert FieldBuilder.resolve_type(%{}, %{}) == :text
    end
  end

  describe "sort_by_order/2" do
    test "sorts fields per the order list with unordered appended" do
      fields = [
        %{name: :a},
        %{name: :b},
        %{name: :c},
        %{name: :d}
      ]

      assert [%{name: :c}, %{name: :a}, %{name: :b}, %{name: :d}] =
               FieldBuilder.sort_by_order(fields, [:c, :a])
    end

    test "no-op when no fields appear in order" do
      fields = [%{name: :a}, %{name: :b}]
      assert FieldBuilder.sort_by_order(fields, [:nonexistent]) == fields
    end

    test "all fields ordered" do
      fields = [%{name: :a}, %{name: :b}, %{name: :c}]

      assert [%{name: :c}, %{name: :b}, %{name: :a}] =
               FieldBuilder.sort_by_order(fields, [:c, :b, :a])
    end
  end

  describe "build_field_config/3" do
    test "merges :attribute, :resolved_label, :resolved_type into field" do
      field = %{name: :title, type: :text}
      attributes = %{title: %{type: Ash.Type.String}}

      result = FieldBuilder.build_field_config(field, attributes, %{})

      assert result.name == :title
      assert result.attribute == %{type: Ash.Type.String}
      assert result.resolved_type == :text
      assert Map.has_key?(result, :resolved_label)
    end

    test "sets :attribute to nil when not in attributes map" do
      field = %{name: :virtual_field, type: :text}
      result = FieldBuilder.build_field_config(field, %{}, %{})
      assert result.attribute == nil
    end
  end

  describe "override pattern" do
    test "user can override resolve_type via use" do
      defmodule TestFieldBuilderOverride do
        use MishkaGervaz.Form.Web.State.FieldBuilder

        def resolve_type(%{name: :special}, _), do: :hidden
        def resolve_type(field, attrs), do: super(field, attrs)
      end

      assert TestFieldBuilderOverride.resolve_type(%{name: :special, type: :text}, %{}) ==
               :hidden

      assert TestFieldBuilderOverride.resolve_type(%{name: :other, type: :textarea}, %{}) ==
               :textarea
    end
  end
end

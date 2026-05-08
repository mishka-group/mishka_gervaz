defmodule MishkaGervaz.Form.Web.State.GroupBuilderTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.State.GroupBuilder.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.GroupBuilder.Default, as: GroupBuilder
  alias MishkaGervaz.Resource.Info.Form, as: Info
  alias MishkaGervaz.Test.Resources.FormPost

  describe "build/2" do
    test "returns groups with :resolved_label" do
      config = Info.config(FormPost)
      result = GroupBuilder.build(config, FormPost)

      assert is_list(result)

      for group <- result do
        assert is_map(group)
        assert Map.has_key?(group, :name)
        assert Map.has_key?(group, :resolved_label)
      end
    end

    test "returns [] for non-map config" do
      assert GroupBuilder.build(nil, FormPost) == []
      assert GroupBuilder.build(:atom, FormPost) == []
    end
  end

  describe "assign_fields_to_groups/2" do
    test "attaches resolved field configs to each group's :resolved_fields" do
      groups = [
        %{name: :general, fields: [:title, :body], resolved_label: "General"},
        %{name: :meta, fields: [:status], resolved_label: "Meta"}
      ]

      fields = [
        %{name: :title, type: :text},
        %{name: :body, type: :textarea},
        %{name: :status, type: :select},
        %{name: :extra, type: :text}
      ]

      [general, meta] = GroupBuilder.assign_fields_to_groups(groups, fields)

      assert Enum.map(general.resolved_fields, & &1.name) == [:title, :body]
      assert Enum.map(meta.resolved_fields, & &1.name) == [:status]
    end

    test "rejects nil entries when a group references a missing field" do
      groups = [%{name: :general, fields: [:title, :ghost]}]
      fields = [%{name: :title, type: :text}]

      [general] = GroupBuilder.assign_fields_to_groups(groups, fields)

      assert Enum.map(general.resolved_fields, & &1.name) == [:title]
    end

    test "preserves the order specified in group :fields list" do
      groups = [%{name: :g, fields: [:c, :a, :b]}]

      fields = [
        %{name: :a, type: :text},
        %{name: :b, type: :text},
        %{name: :c, type: :text}
      ]

      [g] = GroupBuilder.assign_fields_to_groups(groups, fields)
      assert Enum.map(g.resolved_fields, & &1.name) == [:c, :a, :b]
    end

    test "empty groups produce []" do
      groups = [%{name: :empty, fields: []}]
      [empty] = GroupBuilder.assign_fields_to_groups(groups, [%{name: :x}])
      assert empty.resolved_fields == []
    end
  end

  describe "override pattern" do
    test "user can override build via use" do
      defmodule TestGroupBuilderOverride do
        use MishkaGervaz.Form.Web.State.GroupBuilder

        def build(_config, _resource) do
          [%{name: :forced, resolved_label: "Forced"}]
        end
      end

      assert [%{name: :forced}] = TestGroupBuilderOverride.build(%{}, nil)
    end
  end
end

defmodule MishkaGervaz.Table.Behaviours.TemplateTest do
  @moduledoc """
  Tests for the Template behaviour helper functions.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Behaviours.Template

  describe "all_features/0" do
    test "returns all valid features" do
      features = Template.all_features()

      assert is_list(features)
      assert :sort in features
      assert :filter in features
      assert :select in features
      assert :bulk_actions in features
      assert :paginate in features
      assert :export in features
      assert :expand in features
      assert :reorder in features
      assert :inline_edit in features
    end

    test "returns exactly 9 features" do
      features = Template.all_features()

      assert length(features) == 9
    end
  end

  describe "normalize_features/1" do
    test "converts :all to full list" do
      features = Template.normalize_features(:all)

      assert is_list(features)
      assert features == Template.all_features()
    end

    test "returns list unchanged" do
      input = [:sort, :filter, :paginate]
      features = Template.normalize_features(input)

      assert features == input
    end

    test "returns empty list unchanged" do
      features = Template.normalize_features([])

      assert features == []
    end
  end

  describe "feature_enabled?/2" do
    test "returns true for any feature when :all" do
      assert Template.feature_enabled?(:all, :sort)
      assert Template.feature_enabled?(:all, :filter)
      assert Template.feature_enabled?(:all, :bulk_actions)
      assert Template.feature_enabled?(:all, :export)
    end

    test "returns true when feature is in list" do
      features = [:sort, :filter, :paginate]

      assert Template.feature_enabled?(features, :sort)
      assert Template.feature_enabled?(features, :filter)
      assert Template.feature_enabled?(features, :paginate)
    end

    test "returns false when feature is not in list" do
      features = [:sort, :filter, :paginate]

      refute Template.feature_enabled?(features, :bulk_actions)
      refute Template.feature_enabled?(features, :export)
      refute Template.feature_enabled?(features, :expand)
    end

    test "returns false for empty list" do
      features = []

      refute Template.feature_enabled?(features, :sort)
      refute Template.feature_enabled?(features, :filter)
    end
  end
end

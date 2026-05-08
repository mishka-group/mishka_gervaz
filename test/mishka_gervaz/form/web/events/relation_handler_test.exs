defmodule MishkaGervaz.Form.Web.Events.RelationHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.RelationHandler` top-level
  helpers — the pure, side-effect-free functions extracted out of the
  `do_handle/4` clauses.

  Full event dispatch (`handle/4` → `do_handle/4`) is exercised via
  integration in `events_test.exs` since it requires a real socket.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.RelationHandler

  describe "get_search_term/2" do
    test "prefers `_search_<field>` key when present" do
      params = %{"_search_tags" => "abc", "value" => "ignored"}
      assert RelationHandler.get_search_term(params, :tags) == {:ok, "abc"}
    end

    test "falls back to \"value\" when no _search key" do
      params = %{"value" => "fallback"}
      assert RelationHandler.get_search_term(params, :tags) == {:ok, "fallback"}
    end

    test "returns empty string when neither present" do
      assert RelationHandler.get_search_term(%{}, :tags) == {:ok, ""}
    end
  end

  describe "validate_min_chars/2" do
    test "ok when search term meets min-chars" do
      assert RelationHandler.validate_min_chars("hello", %{"min-chars" => "3"}) == :ok
    end

    test "error when search term too short" do
      assert RelationHandler.validate_min_chars("hi", %{"min-chars" => "3"}) ==
               {:error, :below_min_chars}
    end

    test "default min-chars is 1" do
      assert RelationHandler.validate_min_chars("a", %{}) == :ok
      assert RelationHandler.validate_min_chars("", %{}) == {:error, :below_min_chars}
    end
  end

  describe "get_toggle_params/2" do
    test "extracts {value, label} from params" do
      assert RelationHandler.get_toggle_params(%{"id" => "1", "label" => "Acme"}) ==
               {:ok, "1", "Acme"}
    end

    test "defaults to empty strings when missing" do
      assert RelationHandler.get_toggle_params(%{}) == {:ok, "", ""}
    end

    test "stringifies non-string id" do
      assert RelationHandler.get_toggle_params(%{"id" => 42, "label" => "L"}) ==
               {:ok, "42", "L"}
    end
  end

  describe "get_current_opts/2" do
    test "returns the relation options for the given field" do
      state = %{relation_options: %{tags: %{options: [{"a", "1"}], loading?: false}}}

      assert RelationHandler.get_current_opts(state, :tags) ==
               %{options: [{"a", "1"}], loading?: false}
    end

    test "returns %{} when no options stored" do
      assert RelationHandler.get_current_opts(%{relation_options: %{}}, :tags) == %{}
    end
  end

  describe "get_current_selected_list/2" do
    test "list of values: stringified and empty/nil rejected" do
      state = %{field_values: %{tags: ["a", nil, "", "b"]}}

      assert RelationHandler.get_current_selected_list(state, :tags) == ["a", "b"]
    end

    test "single value wrapped in a list" do
      state = %{field_values: %{site_id: "uuid-1"}}
      assert RelationHandler.get_current_selected_list(state, :site_id) == ["uuid-1"]
    end

    test "nil / empty / empty-list values return []" do
      assert RelationHandler.get_current_selected_list(%{field_values: %{x: nil}}, :x) == []
      assert RelationHandler.get_current_selected_list(%{field_values: %{x: ""}}, :x) == []
      assert RelationHandler.get_current_selected_list(%{field_values: %{x: []}}, :x) == []
    end
  end

  describe "prepend_selected/2 + reject_selected/2" do
    test "prepend keeps selected options at the front" do
      assert RelationHandler.prepend_selected([{"S", "1"}], [{"O", "2"}, {"P", "3"}]) ==
               [{"S", "1"}, {"O", "2"}, {"P", "3"}]
    end

    test "prepend deduplicates against options by value" do
      assert RelationHandler.prepend_selected([{"S", "1"}], [{"S", "1"}, {"O", "2"}]) ==
               [{"S", "1"}, {"O", "2"}]
    end

    test "prepend with empty selected returns options unchanged" do
      assert RelationHandler.prepend_selected([], [{"O", "2"}]) == [{"O", "2"}]
    end

    test "reject removes options that match selected values" do
      assert RelationHandler.reject_selected([{"S", "1"}], [{"S", "1"}, {"O", "2"}]) ==
               [{"O", "2"}]
    end

    test "reject is no-op for empty selected" do
      assert RelationHandler.reject_selected([], [{"O", "2"}]) == [{"O", "2"}]
    end
  end

  describe "toggle_value/3" do
    test "adds value when not currently selected (4th arg false)" do
      assert RelationHandler.toggle_value(["a"], "b", false) == ["a", "b"]
    end

    test "removes value when currently selected (4th arg true)" do
      assert RelationHandler.toggle_value(["a", "b", "c"], "b", true) == ["a", "c"]
    end
  end

  describe "toggle_selected_option/5" do
    test "adds {label, value} when not currently selected" do
      state = %{relation_options: %{tags: %{selected_options: [{"A", "1"}]}}}

      assert RelationHandler.toggle_selected_option(state, :tags, "2", "B", false) ==
               [{"A", "1"}, {"B", "2"}]
    end

    test "removes the matching pair when currently selected" do
      state = %{relation_options: %{tags: %{selected_options: [{"A", "1"}, {"B", "2"}]}}}

      assert RelationHandler.toggle_selected_option(state, :tags, "2", "B", true) ==
               [{"A", "1"}]
    end
  end
end

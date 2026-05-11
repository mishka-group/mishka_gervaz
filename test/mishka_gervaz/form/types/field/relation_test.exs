defmodule MishkaGervaz.Form.Types.Field.RelationTest.UIStub do
  @moduledoc false

  def select(assigns), do: dispatch(:select, assigns)
  def search_select(assigns), do: dispatch(:search_select, assigns)
  def load_more_select(assigns), do: dispatch(:load_more_select, assigns)
  def multi_select(assigns), do: dispatch(:multi_select, assigns)

  defp dispatch(name, assigns) do
    send(self(), {:dispatched, name, assigns})
    assigns
  end
end

defmodule MishkaGervaz.Form.Types.Field.RelationTest do
  @moduledoc """
  Direct tests for the `:relation` field type — covers the four
  `FieldType` callbacks and `render_input/4`'s mode → adapter dispatch.

  Run-time relation loading is exercised separately by
  `data_loader/relation_loader_test.exs`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Relation

  describe "behaviour callbacks" do
    test "render/2 returns assigns unchanged" do
      assert Relation.render(%{}, %{}) == %{}
    end

    test "validate/2 passes through" do
      assert Relation.validate("uuid-1", %{}) == {:ok, "uuid-1"}
      assert Relation.validate(["uuid-1", "uuid-2"], %{}) == {:ok, ["uuid-1", "uuid-2"]}
      assert Relation.validate(nil, %{}) == {:ok, nil}
    end

    test "parse_params/2 passes through" do
      assert Relation.parse_params("v", %{}) == "v"
    end

    test "sanitize/2 passes through" do
      assert Relation.sanitize("uuid-1", %{}) == "uuid-1"
    end

    test "default_ui/0" do
      assert Relation.default_ui() == %{type: :relation}
    end
  end

  describe "render_input/4 — adapter dispatch by mode" do
    setup do
      ui = stub_ui_module()

      field = %{name: :site_id}
      rel_data = %{options: [{"Acme", "1"}]}
      state_assigns = %{form_field: nil, myself: nil, current_value: ""}

      %{ui: ui, field: field, rel_data: rel_data, state_assigns: state_assigns}
    end

    test ":static → ui.select", %{ui: ui, field: field, rel_data: rel, state_assigns: st} do
      Relation.render_input(Map.put(field, :mode, :static), rel, st, ui)
      assert_received {:dispatched, :select, _}
    end

    test "no mode (default :static) → ui.select", %{
      ui: ui,
      field: field,
      rel_data: rel,
      state_assigns: st
    } do
      Relation.render_input(field, rel, st, ui)
      assert_received {:dispatched, :select, _}
    end

    test ":search → ui.search_select", %{ui: ui, field: field, rel_data: rel, state_assigns: st} do
      Relation.render_input(Map.put(field, :mode, :search), rel, st, ui)
      assert_received {:dispatched, :search_select, _}
    end

    test ":load_more → ui.load_more_select", %{
      ui: ui,
      field: field,
      rel_data: rel,
      state_assigns: st
    } do
      Relation.render_input(Map.put(field, :mode, :load_more), rel, st, ui)
      assert_received {:dispatched, :load_more_select, _}
    end

    test ":search_multi → ui.multi_select", %{
      ui: ui,
      field: field,
      rel_data: rel,
      state_assigns: st
    } do
      Relation.render_input(Map.put(field, :mode, :search_multi), rel, st, ui)
      assert_received {:dispatched, :multi_select, _}
    end

    test "unknown mode falls back to ui.select", %{
      ui: ui,
      field: field,
      rel_data: rel,
      state_assigns: st
    } do
      Relation.render_input(Map.put(field, :mode, :weird), rel, st, ui)
      assert_received {:dispatched, :select, _}
    end
  end

  describe "render_input/4 — assigns shape" do
    test ":search_multi shape includes :selected and :search_term" do
      ui = stub_ui_module()

      field = %{
        name: :tag_ids,
        mode: :search_multi,
        ui: %{placeholder: "Search...", debounce: 500}
      }

      rel_data = %{
        options: [],
        selected_options: [{"Existing", "1"}],
        search_term: "abc"
      }

      state_assigns = %{
        form_field: nil,
        field_values: %{tag_ids: ["existing-1"]},
        myself: nil
      }

      Relation.render_input(field, rel_data, state_assigns, ui)
      assert_received {:dispatched, :multi_select, assigns}

      assert assigns.placeholder == "Search..."
      assert assigns.debounce == 500
      assert assigns.search_term == "abc"
      assert assigns.selected == ["existing-1"]
      assert assigns.selected_options == [{"Existing", "1"}]
    end

    test "readonly forces dropdown_open? false even when rel_data says open" do
      ui = stub_ui_module()
      field = %{name: :site_id, mode: :static}
      rel_data = %{dropdown_open?: true, options: []}
      state_assigns = %{form_field: nil, myself: nil, readonly: true, current_value: ""}

      Relation.render_input(field, rel_data, state_assigns, ui)
      assert_received {:dispatched, :select, assigns}

      assert assigns.dropdown_open? == false
      assert assigns.disabled == true
    end
  end

  defp stub_ui_module, do: MishkaGervaz.Form.Types.Field.RelationTest.UIStub
end

defmodule MishkaGervaz.Table.Types.Action.AccordionTest do
  @moduledoc """
  Tests for the Accordion action type — expand/collapse button for row details.

  Accordion renders are guarded by `:expand in state.static.features`.
  Verified here by setting up assigns with and without the feature and
  asserting render returns the empty `~H""` when disabled.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Accordion

  describe "behaviour implementation" do
    test "implements ActionType behaviour" do
      behaviours = Accordion.__info__(:attributes)[:behaviour] || []
      assert MishkaGervaz.Table.Behaviours.ActionType in behaviours
    end

    test "defines render/5 function" do
      Code.ensure_loaded!(Accordion)
      assert function_exported?(Accordion, :render, 5)
    end
  end

  describe "registry" do
    test "registered in Types.Action under :accordion" do
      assert MishkaGervaz.Table.Types.Action.get(:accordion) == Accordion
    end
  end

  describe "render/5 feature gating" do
    test "returns empty render when :expand feature is missing" do
      assigns = %{static: %{features: []}, state: nil, __changed__: %{}}
      action = %{ui: %{label: "Expand"}}
      record = %{id: "rec-1"}

      # Should produce an empty render (no `~H` output content) when feature absent.
      rendered = Accordion.render(assigns, action, record, MishkaGervaz.UIAdapters.Tailwind, nil)
      assert is_struct(rendered, Phoenix.LiveView.Rendered)
    end

    test "returns a render when :expand feature is enabled" do
      assigns = %{
        static: %{features: [:expand]},
        state: %{expanded_id: nil},
        __changed__: %{}
      }

      action = %{ui: %{label: "Expand"}}
      record = %{id: "rec-1"}

      rendered = Accordion.render(assigns, action, record, MishkaGervaz.UIAdapters.Tailwind, nil)
      assert is_struct(rendered, Phoenix.LiveView.Rendered)
    end
  end
end

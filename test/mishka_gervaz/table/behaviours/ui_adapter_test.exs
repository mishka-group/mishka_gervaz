defmodule MishkaGervaz.Behaviours.UIAdapterTest do
  @moduledoc """
  Tests for the UIAdapter behaviour.
  """
  use ExUnit.Case, async: true

  describe "behaviour callbacks" do
    test "defines required component callbacks" do
      callbacks = MishkaGervaz.Behaviours.UIAdapter.behaviour_info(:callbacks)

      # Input components
      assert {:text_input, 1} in callbacks
      assert {:select, 1} in callbacks
      assert {:checkbox, 1} in callbacks
      assert {:date_input, 1} in callbacks
      assert {:datetime_input, 1} in callbacks
      assert {:number_input, 1} in callbacks

      # Action components
      assert {:button, 1} in callbacks
      assert {:nav_link, 1} in callbacks

      # Display components
      assert {:icon, 1} in callbacks
      assert {:badge, 1} in callbacks
      assert {:spinner, 1} in callbacks

      # Table components
      assert {:table, 1} in callbacks
      assert {:table_header, 1} in callbacks
      assert {:th, 1} in callbacks
      assert {:tr, 1} in callbacks
      assert {:td, 1} in callbacks
    end

    test "defines optional callbacks" do
      optional = MishkaGervaz.Behaviours.UIAdapter.behaviour_info(:optional_callbacks)

      assert {:dropdown, 1} in optional
      assert {:empty_state, 1} in optional
      assert {:error_state, 1} in optional
    end
  end

  describe "module attributes" do
    test "tailwind adapter is defined" do
      assert Code.ensure_loaded?(MishkaGervaz.UIAdapters.Tailwind)
    end
  end
end

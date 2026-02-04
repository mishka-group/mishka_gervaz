defmodule MishkaGervaz.Table.Dsl.EventsDslTest do
  @moduledoc """
  Tests for Events DSL configuration.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Table, as: Info

  # Aliases to resources in test/support/resources/events_dsl_resources.ex
  alias MishkaGervaz.Test.EventsDsl.{
    CustomSanitizationHandler,
    CustomRecordHandler,
    CustomSelectionHandler,
    CustomBulkActionHandler,
    CustomHookRunner,
    CustomRelationFilterHandler,
    CustomEventsModule,
    CustomSanitizationResource,
    CustomRecordResource,
    CustomFullResource,
    CustomModuleResource,
    BasicResource
  }

  describe "DSL events entity configuration" do
    test "resource with custom sanitization handler returns correct config" do
      config = Info.events(CustomSanitizationResource)

      assert config[:sanitization] == CustomSanitizationHandler
      assert config[:record] == nil
      assert config[:selection] == nil
      assert config[:module] == nil
    end

    test "resource with custom record handler returns correct config" do
      config = Info.events(CustomRecordResource)

      assert config[:record] == CustomRecordHandler
      assert config[:sanitization] == nil
      assert config[:selection] == nil
      assert config[:module] == nil
    end

    test "resource with multiple custom sub-builders returns all overrides" do
      config = Info.events(CustomFullResource)

      assert config[:sanitization] == CustomSanitizationHandler
      assert config[:record] == CustomRecordHandler
      assert config[:selection] == CustomSelectionHandler
      assert config[:bulk_action] == CustomBulkActionHandler
      assert config[:hooks] == CustomHookRunner
      assert config[:relation_filter] == CustomRelationFilterHandler
      assert config[:module] == nil
    end

    test "resource with custom module (positional arg) returns module config" do
      config = Info.events(CustomModuleResource)

      assert config[:module] == CustomEventsModule
      # Sub-builder keys should be nil when module is set
      assert config[:sanitization] == nil
      assert config[:record] == nil
    end

    test "resource without custom events returns empty config" do
      config = Info.events(BasicResource)

      assert config == %{}
    end
  end

  describe "Config transformer persists events settings" do
    test "events is included in persisted config" do
      config = Info.config(CustomSanitizationResource)

      assert is_map(config[:events])
      assert config[:events][:sanitization] == CustomSanitizationHandler
    end

    test "full config includes events with all sub-builders" do
      config = Info.config(CustomFullResource)

      assert config[:events][:sanitization] == CustomSanitizationHandler
      assert config[:events][:record] == CustomRecordHandler
      assert config[:events][:selection] == CustomSelectionHandler
      assert config[:events][:bulk_action] == CustomBulkActionHandler
      assert config[:events][:hooks] == CustomHookRunner
      assert config[:events][:relation_filter] == CustomRelationFilterHandler
    end

    test "module override is correctly persisted" do
      config = Info.config(CustomModuleResource)

      assert config[:events][:module] == CustomEventsModule
    end

    test "resource without events has nil in config" do
      config = Info.config(BasicResource)

      # events should be nil when not configured
      assert config[:events] == nil
    end
  end

  describe "DSL validation" do
    test "events entity can coexist with other table DSL elements" do
      config = Info.config(CustomSanitizationResource)

      # Verify other DSL elements still work
      assert config[:identity][:name] == :custom_sanitization_items
      assert config[:identity][:route] == "/admin/custom-sanitization"
      assert config[:pagination][:page_size] == 5
      assert config[:pagination][:type] == :numbered
    end

    test "events with positional arg is valid syntax" do
      config = Info.config(CustomModuleResource)

      # Should compile and have correct identity
      assert config[:identity][:name] == :custom_module_items
      assert config[:identity][:route] == "/admin/custom-module"
    end
  end

  describe "Custom handler behavior" do
    test "custom sanitization handler transforms input" do
      # Test the custom sanitization handler
      result = CustomSanitizationHandler.sanitize("<script>hello</script>")
      assert result == "HELLO"
    end

    test "custom selection handler limits selection" do
      alias MishkaGervaz.Table.Web.State

      static = %State.Static{
        id: "test",
        resource: BasicResource,
        stream_name: :test_stream
      }

      state = %State{
        static: static,
        current_user: %{id: "1", role: :admin},
        master_user?: true,
        selected_ids: MapSet.new(["1", "2", "3", "4", "5"]),
        excluded_ids: MapSet.new(),
        select_all?: false
      }

      # Should not add more when at limit
      new_state = CustomSelectionHandler.toggle_select(state, "6")
      assert MapSet.size(new_state.selected_ids) == 5
      refute MapSet.member?(new_state.selected_ids, "6")
    end
  end
end

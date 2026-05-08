defmodule MishkaGervaz.Behaviours.UIAdapterTest do
  @moduledoc """
  Tests for `MishkaGervaz.Behaviours.UIAdapter` — the contract surface and
  every supported configuration of `use MishkaGervaz.Behaviours.UIAdapter`.

  Each adapter under test is built against fixture fallback/components
  modules that return tagged tuples instead of `Phoenix.LiveView.Rendered.t()`.
  This lets us assert which target the adapter actually called, since
  `defdelegate` does not leave a runtime trace.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Behaviours.UIAdapter

  # ----- Fixtures -----------------------------------------------------------

  @callback_names UIAdapter.behaviour_info(:callbacks)
                  |> Enum.map(&elem(&1, 0))

  defmodule FallbackFixture do
    @moduledoc false
    use Phoenix.Component

    for {func, 1} <- MishkaGervaz.Behaviours.UIAdapter.behaviour_info(:callbacks) do
      def unquote(func)(_assigns), do: {:fallback, unquote(func)}
    end
  end

  defmodule ComponentsFlatFixture do
    @moduledoc false
    def button(_assigns), do: {:components_flat, :button}
    def icon(_assigns), do: {:components_flat, :icon}
    # text_input, select, etc. NOT defined — should fall back.
  end

  defmodule ComponentsNestedFixture do
    @moduledoc false
    defmodule Button do
      def button(_assigns), do: {:components_nested, :button}
    end

    defmodule Icon do
      def icon(_assigns), do: {:components_nested, :icon}
    end
  end

  defmodule ComponentsPrefixedModuleFixture do
    @moduledoc false
    defmodule MishkaButton do
      def button(_assigns), do: {:prefixed_module, :button}
    end
  end

  defmodule ComponentsPrefixedFunctionFixture do
    @moduledoc false
    def mc_button(_assigns), do: {:prefixed_fn, :button}
    def mc_icon(_assigns), do: {:prefixed_fn, :icon}
  end

  defmodule ComponentsBothPrefixesFixture do
    @moduledoc false
    defmodule MishkaButton do
      def mc_button(_assigns), do: {:both, :button}
    end
  end

  # Adapters under test
  defmodule AdapterFallbackOnly do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture
  end

  defmodule AdapterFlatComponents do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture,
      components: MishkaGervaz.Behaviours.UIAdapterTest.ComponentsFlatFixture
  end

  defmodule AdapterNestedComponents do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture,
      components: MishkaGervaz.Behaviours.UIAdapterTest.ComponentsNestedFixture,
      nested_components: true
  end

  defmodule AdapterPrefixedModule do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture,
      components: MishkaGervaz.Behaviours.UIAdapterTest.ComponentsPrefixedModuleFixture,
      nested_components: true,
      module_prefix: "Mishka"
  end

  defmodule AdapterPrefixedFunction do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture,
      components: MishkaGervaz.Behaviours.UIAdapterTest.ComponentsPrefixedFunctionFixture,
      component_prefix: "mc_"
  end

  defmodule AdapterBothPrefixes do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture,
      components: MishkaGervaz.Behaviours.UIAdapterTest.ComponentsBothPrefixesFixture,
      nested_components: true,
      module_prefix: "Mishka",
      component_prefix: "mc_"
  end

  defmodule AdapterUserOverride do
    @moduledoc false

    use MishkaGervaz.Behaviours.UIAdapter,
      fallback: MishkaGervaz.Behaviours.UIAdapterTest.FallbackFixture

    def button(_assigns), do: {:user_override, :button}
  end

  # ----- Behaviour contract ------------------------------------------------

  describe "behaviour callbacks" do
    test "every callback has arity 1" do
      assert Enum.all?(UIAdapter.behaviour_info(:callbacks), &match?({_, 1}, &1))
    end

    test "core input/action/display callbacks are declared" do
      callbacks = UIAdapter.behaviour_info(:callbacks)

      for name <- ~w(text_input select checkbox date_input datetime_input number_input
                     button nav_link icon badge spinner)a do
        assert {name, 1} in callbacks, "missing required callback: #{name}/1"
      end
    end

    test "table-cluster callbacks are declared" do
      callbacks = UIAdapter.behaviour_info(:callbacks)

      for name <- ~w(table table_header th tr td bulk_action_bar bulk_action_button
                     pagination_container pagination_nav_button pagination_page_button
                     archive_toggle filter_reset_button)a do
        assert {name, 1} in callbacks, "missing table callback: #{name}/1"
      end
    end

    test "form-cluster callbacks are declared" do
      callbacks = UIAdapter.behaviour_info(:callbacks)

      for name <- ~w(form_container field_wrapper field_group step_indicator
                     step_navigation upload_dropzone upload_preview upload_progress
                     toggle_input range_input textarea json_editor nested_fields
                     array_fields field_error string_list_input password_input
                     combobox alert form_header form_footer)a do
        assert {name, 1} in callbacks, "missing form callback: #{name}/1"
      end
    end

    test "every callback is marked optional (because use provides defaults)" do
      callbacks = UIAdapter.behaviour_info(:callbacks) |> MapSet.new()
      optional = UIAdapter.behaviour_info(:optional_callbacks) |> MapSet.new()

      missing = MapSet.difference(callbacks, optional)

      assert MapSet.size(missing) == 0,
             "callbacks not marked optional (will warn if hand-rolled): #{inspect(MapSet.to_list(missing))}"
    end
  end

  # ----- use: fallback only -----------------------------------------------

  describe "use without :components — every function delegates to fallback" do
    test "button delegates to fallback" do
      assert AdapterFallbackOnly.button(%{}) == {:fallback, :button}
    end

    test "text_input delegates to fallback" do
      assert AdapterFallbackOnly.text_input(%{}) == {:fallback, :text_input}
    end

    test "form_footer delegates to fallback" do
      assert AdapterFallbackOnly.form_footer(%{}) == {:fallback, :form_footer}
    end

    test "every declared callback resolves through the adapter to fallback" do
      for name <- @callback_names do
        result = apply(AdapterFallbackOnly, name, [%{}])

        assert result == {:fallback, name},
               "expected fallback for #{name}, got #{inspect(result)}"
      end
    end
  end

  # ----- use: flat components ---------------------------------------------

  describe "use with :components (flat)" do
    test "overridden function calls components module" do
      assert AdapterFlatComponents.button(%{}) == {:components_flat, :button}
      assert AdapterFlatComponents.icon(%{}) == {:components_flat, :icon}
    end

    test "non-overridden function falls back" do
      assert AdapterFlatComponents.text_input(%{}) == {:fallback, :text_input}
      assert AdapterFlatComponents.form_container(%{}) == {:fallback, :form_container}
    end
  end

  # ----- use: nested components -------------------------------------------

  describe "use with :components and nested_components: true" do
    test "uses Components.Button.button/1" do
      assert AdapterNestedComponents.button(%{}) == {:components_nested, :button}
    end

    test "uses Components.Icon.icon/1" do
      assert AdapterNestedComponents.icon(%{}) == {:components_nested, :icon}
    end

    test "non-existent submodule falls back to fallback" do
      assert AdapterNestedComponents.text_input(%{}) == {:fallback, :text_input}
    end
  end

  # ----- use: module_prefix -----------------------------------------------

  describe "use with :module_prefix" do
    test "looks up Components.MishkaButton.button/1" do
      assert AdapterPrefixedModule.button(%{}) == {:prefixed_module, :button}
    end

    test "non-prefixed submodule falls back" do
      # Components has no `Icon` (only `MishkaButton`), so fallback.
      assert AdapterPrefixedModule.icon(%{}) == {:fallback, :icon}
    end
  end

  # ----- use: component_prefix --------------------------------------------

  describe "use with :component_prefix" do
    test "looks up Components.mc_button/1 (flat with function prefix)" do
      assert AdapterPrefixedFunction.button(%{}) == {:prefixed_fn, :button}
      assert AdapterPrefixedFunction.icon(%{}) == {:prefixed_fn, :icon}
    end

    test "function without mc_ prefix falls back" do
      assert AdapterPrefixedFunction.text_input(%{}) == {:fallback, :text_input}
    end
  end

  # ----- use: both prefixes ------------------------------------------------

  describe "use with both :module_prefix and :component_prefix" do
    test "looks up Components.MishkaButton.mc_button/1" do
      assert AdapterBothPrefixes.button(%{}) == {:both, :button}
    end

    test "missing combo falls back" do
      assert AdapterBothPrefixes.icon(%{}) == {:fallback, :icon}
    end
  end

  # ----- defoverridable ---------------------------------------------------

  describe "user-defined override after use" do
    test "explicit def takes precedence over the generated defdelegate" do
      assert AdapterUserOverride.button(%{}) == {:user_override, :button}
    end

    test "non-overridden functions still delegate to fallback" do
      assert AdapterUserOverride.text_input(%{}) == {:fallback, :text_input}
    end
  end

  # ----- module shape -----------------------------------------------------

  describe "generated adapter module shape" do
    test "implements the UIAdapter behaviour" do
      behaviours = AdapterFallbackOnly.module_info(:attributes) |> Keyword.get(:behaviour, [])
      assert UIAdapter in behaviours
    end

    test "exports every callback as a 1-arity function" do
      exports = AdapterFallbackOnly.__info__(:functions) |> MapSet.new()

      for name <- @callback_names do
        assert {name, 1} in exports, "adapter is missing #{name}/1"
      end
    end
  end
end

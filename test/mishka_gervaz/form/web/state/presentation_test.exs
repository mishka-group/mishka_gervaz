defmodule MishkaGervaz.Form.Web.State.PresentationTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.State.Presentation.Default`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.Presentation.Default, as: Presentation

  describe "resolve_ui_adapter/1" do
    test "returns Tailwind by default" do
      assert Presentation.resolve_ui_adapter(%{}) == MishkaGervaz.UIAdapters.Tailwind
      assert Presentation.resolve_ui_adapter(nil) == MishkaGervaz.UIAdapters.Tailwind
    end

    test ":tailwind atom resolves to Tailwind module" do
      assert Presentation.resolve_ui_adapter(%{presentation: %{ui_adapter: :tailwind}}) ==
               MishkaGervaz.UIAdapters.Tailwind
    end

    test "explicit module passes through" do
      assert Presentation.resolve_ui_adapter(%{presentation: %{ui_adapter: My.Adapter}}) ==
               My.Adapter
    end
  end

  describe "get_ui_adapter_opts/1" do
    test "returns [] when missing" do
      assert Presentation.get_ui_adapter_opts(%{}) == []
      assert Presentation.get_ui_adapter_opts(nil) == []
    end

    test "returns the configured opts" do
      assert Presentation.get_ui_adapter_opts(%{
               presentation: %{ui_adapter_opts: [variant: :compact]}
             }) == [variant: :compact]
    end
  end

  describe "resolve_template/1" do
    test "returns Standard by default" do
      assert Presentation.resolve_template(%{}) == MishkaGervaz.Form.Templates.Standard
      assert Presentation.resolve_template(nil) == MishkaGervaz.Form.Templates.Standard
    end

    test ":standard atom resolves to Standard module" do
      assert Presentation.resolve_template(%{presentation: %{template: :standard}}) ==
               MishkaGervaz.Form.Templates.Standard
    end

    test "explicit module passes through" do
      assert Presentation.resolve_template(%{presentation: %{template: My.Template}}) ==
               My.Template
    end
  end

  describe "get_theme/1" do
    test "returns nil when missing" do
      assert Presentation.get_theme(%{}) == nil
      assert Presentation.get_theme(nil) == nil
    end

    test "returns configured theme map" do
      theme = %{primary: "blue"}
      assert Presentation.get_theme(%{presentation: %{theme: theme}}) == theme
    end
  end

  describe "get_features/1" do
    @default_features [:validation, :uploads, :groups, :wizard, :autosave, :inline_errors]

    test "returns all default features when missing" do
      assert Presentation.get_features(%{}) == @default_features
      assert Presentation.get_features(nil) == @default_features
    end

    test ":all atom resolves to all default features" do
      assert Presentation.get_features(%{presentation: %{features: :all}}) ==
               @default_features
    end

    test "explicit list passes through" do
      assert Presentation.get_features(%{presentation: %{features: [:validation]}}) ==
               [:validation]
    end

    test "non-atom non-list falls back to default" do
      assert Presentation.get_features(%{presentation: %{features: "weird"}}) ==
               @default_features
    end
  end

  describe "get_debounce/1" do
    test "returns nil when missing" do
      assert Presentation.get_debounce(%{}) == nil
      assert Presentation.get_debounce(nil) == nil
    end

    test "returns the configured integer" do
      assert Presentation.get_debounce(%{presentation: %{debounce: 300}}) == 300
    end
  end

  describe "override pattern" do
    test "user can override resolve_ui_adapter via use" do
      defmodule TestPresentationOverride do
        use MishkaGervaz.Form.Web.State.Presentation

        def resolve_ui_adapter(%{theme: :dark}), do: My.DarkAdapter
        def resolve_ui_adapter(config), do: super(config)
      end

      assert TestPresentationOverride.resolve_ui_adapter(%{theme: :dark}) == My.DarkAdapter

      assert TestPresentationOverride.resolve_ui_adapter(%{}) ==
               MishkaGervaz.UIAdapters.Tailwind
    end
  end
end

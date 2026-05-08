defmodule MishkaGervaz.UIAdapters.DynamicTest do
  @moduledoc """
  Tests for `MishkaGervaz.UIAdapters.Dynamic`.

  Three contracts are pinned:

  1. **Wiring** — every callback declared on the UIAdapter behaviour is
     implemented on `Dynamic` (no missing functions).

  2. **Fallback path** — when no `:__component_renderer__` is on the
     assigns, every callback delegates to the configured fallback adapter.
     Verified with a sentinel fallback that emits `{:fallback, name}` so
     the routing is observable.

  3. **Renderer path** — when both a renderer and a resolver pointing at a
     loaded module are present, the renderer is invoked with
     `:component_name` and `:site` injected into the assigns.

  Plus tests for `with_config/2` and the `__using__` macro.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.UIAdapters.Dynamic

  # ----- Sentinel fallback -------------------------------------------------

  defmodule SentinelFallback do
    @moduledoc false
    use Phoenix.Component

    for {func, 1} <- MishkaGervaz.Behaviours.UIAdapter.behaviour_info(:callbacks) do
      name = Atom.to_string(func)

      def unquote(func)(assigns) do
        assigns = Phoenix.Component.assign(assigns, :__sentinel_name__, unquote(name))

        ~H"""
        <span data-fallback={@__sentinel_name__}></span>
        """
      end
    end
  end

  defmodule SentinelRenderer do
    @moduledoc false
    use Phoenix.Component

    def component(assigns) do
      ~H"""
      <span
        data-renderer={@component_name}
        data-site={@site}
      >
      </span>
      """
    end
  end

  # ----- Contract: every behaviour callback is implemented -----------------

  describe "wiring" do
    test "Dynamic exports every callback declared on the behaviour" do
      exports = Dynamic.__info__(:functions) |> MapSet.new()

      for name <- MishkaGervaz.Behaviours.UIAdapter.component_functions() do
        assert {name, 1} in exports, "Dynamic is missing #{name}/1"
      end
    end

    test "Dynamic declares the UIAdapter behaviour" do
      attrs = Dynamic.module_info(:attributes) |> Keyword.get(:behaviour, [])
      assert MishkaGervaz.Behaviours.UIAdapter in attrs
    end

    test "previously-missing callbacks are now wired" do
      exports = Dynamic.__info__(:functions) |> MapSet.new()
      assert {:alert, 1} in exports
      assert {:form_header, 1} in exports
      assert {:form_footer, 1} in exports
      assert {:password_input, 1} in exports
    end
  end

  # ----- Fallback path ----------------------------------------------------

  describe "fallback path — no renderer configured" do
    test "every callback emits the fallback sentinel when assigns lack a renderer" do
      base = Dynamic.with_config(%{}, fallback: SentinelFallback)

      for name <- MishkaGervaz.Behaviours.UIAdapter.component_functions() do
        html = render_component(Function.capture(Dynamic, name, 1), base)

        assert html =~ ~s(data-fallback="#{name}"),
               "Dynamic.#{name}/1 did not delegate to fallback (got: #{html})"
      end
    end

    test "default fallback is Tailwind when none is set on the assigns" do
      # No :__fallback__ on assigns ⇒ Dynamic.fallback/1 returns the
      # default (Tailwind), and the call routes through it.
      html = render_component(&Dynamic.button/1, %{label: "x"})
      assert html =~ "<button"
    end
  end

  # ----- Renderer path ----------------------------------------------------

  describe "renderer path" do
    test "calls the renderer with :component_name and :site when resolver returns a loaded module" do
      resolver = fn _name, _site, _kind -> SentinelFallback end

      assigns =
        Dynamic.with_config(%{},
          site: "TestSite",
          component_renderer: &SentinelRenderer.component/1,
          module_resolver: resolver,
          fallback: SentinelFallback
        )

      html = render_component(&Dynamic.button/1, assigns)

      assert html =~ ~s(data-renderer="button")
      assert html =~ ~s(data-site="TestSite")

      refute html =~ "data-fallback",
             "renderer path should not delegate to fallback"
    end

    test "falls back when the resolver returns an unloaded module" do
      unloaded = Module.concat(__MODULE__, :NotARealModule)
      resolver = fn _name, _site, _kind -> unloaded end

      assigns =
        Dynamic.with_config(%{},
          component_renderer: &SentinelRenderer.component/1,
          module_resolver: resolver,
          fallback: SentinelFallback
        )

      html = render_component(&Dynamic.button/1, assigns)
      assert html =~ ~s(data-fallback="button")
    end

    test "falls back when the resolver is nil even if a renderer is set" do
      assigns =
        Dynamic.with_config(%{},
          component_renderer: &SentinelRenderer.component/1,
          fallback: SentinelFallback
        )

      html = render_component(&Dynamic.button/1, assigns)
      assert html =~ ~s(data-fallback="button")
    end

    test "falls back when the renderer is nil even if a resolver is set" do
      resolver = fn _name, _site, _kind -> SentinelFallback end

      assigns =
        Dynamic.with_config(%{},
          module_resolver: resolver,
          fallback: SentinelFallback
        )

      html = render_component(&Dynamic.button/1, assigns)
      assert html =~ ~s(data-fallback="button")
    end
  end

  # ----- with_config/2 ---------------------------------------------------

  describe "with_config/2" do
    test "sets the four sentinel keys on the assigns" do
      result =
        Dynamic.with_config(%{existing: 1},
          site: "S",
          fallback: SentinelFallback,
          component_renderer: &SentinelRenderer.component/1,
          module_resolver: fn _, _, _ -> nil end
        )

      assert result.existing == 1
      assert result.__site__ == "S"
      assert result.__fallback__ == SentinelFallback
      assert is_function(result.__component_renderer__, 1)
      assert is_function(result.__module_resolver__, 3)
    end

    test "applies defaults when only required opts are passed" do
      result = Dynamic.with_config(%{})
      assert result.__site__ == "Global"
      assert result.__fallback__ == MishkaGervaz.UIAdapters.Tailwind
      refute Map.has_key?(result, :__component_renderer__)
      refute Map.has_key?(result, :__module_resolver__)
    end

    test "does not put nil values for renderer / resolver" do
      result = Dynamic.with_config(%{}, component_renderer: nil, module_resolver: nil)
      refute Map.has_key?(result, :__component_renderer__)
      refute Map.has_key?(result, :__module_resolver__)
    end
  end

  # ----- __using__ macro -------------------------------------------------

  # Always returns SentinelFallback (which IS loaded), so renderer fires.
  # Captured with `&Mod.fun/3` because module attributes can't hold
  # anonymous functions.
  def __resolver__(_name, _site, _kind), do: SentinelFallback

  defmodule ConsumerAdapter do
    @moduledoc false

    use MishkaGervaz.UIAdapters.Dynamic,
      site: "ConsumerSite",
      fallback: MishkaGervaz.UIAdapters.DynamicTest.SentinelFallback,
      component_renderer: &MishkaGervaz.UIAdapters.DynamicTest.SentinelRenderer.component/1,
      module_resolver: &MishkaGervaz.UIAdapters.DynamicTest.__resolver__/3
  end

  describe "use Dynamic" do
    test "consumer adapter exports every callback as a 1-arity function" do
      exports = ConsumerAdapter.__info__(:functions) |> MapSet.new()

      for name <- MishkaGervaz.Behaviours.UIAdapter.component_functions() do
        assert {name, 1} in exports, "ConsumerAdapter is missing #{name}/1"
      end
    end

    test "consumer adapter declares the UIAdapter behaviour" do
      attrs = ConsumerAdapter.module_info(:attributes) |> Keyword.get(:behaviour, [])
      assert MishkaGervaz.Behaviours.UIAdapter in attrs
    end

    test "consumer wraps every call so site / renderer / resolver are injected" do
      html = render_component(&ConsumerAdapter.button/1, %{label: "x"})

      assert html =~ ~s(data-renderer="button")
      assert html =~ ~s(data-site="ConsumerSite")
    end

    test "previously-missing callbacks are wrapped on the consumer too" do
      for name <- ~w(alert form_header form_footer password_input)a do
        html = render_component(Function.capture(ConsumerAdapter, name, 1), %{})

        assert html =~ ~s(data-renderer="#{name}"),
               "ConsumerAdapter.#{name}/1 did not invoke the dynamic renderer"
      end
    end
  end
end

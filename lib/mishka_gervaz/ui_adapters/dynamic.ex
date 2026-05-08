defmodule MishkaGervaz.UIAdapters.Dynamic do
  @moduledoc """
  Dynamic UI adapter for database-driven components.

  Loads components from a database (or any user-supplied source) and renders
  them at runtime. When the configured component is not available, falls
  back to another `MishkaGervaz.Behaviours.UIAdapter` implementation
  (Tailwind by default).

  ## Configuration

  Set this adapter on the DSL with the renderer and resolver:

      presentation do
        ui_adapter :dynamic
        ui_adapter_opts [
          site: "Global",
          component_renderer: &MishkaCmsCore.Runtime.LiveViewHelpers.component/1,
          module_resolver: &MishkaCmsCore.Runtime.Compilers.Helpers.module_name/3,
          fallback: MishkaGervaz.UIAdapters.Tailwind
        ]
      end

  ## Options

    * `:site` — site identifier passed to the renderer (default `"Global"`)
    * `:component_renderer` — `(assigns) -> Phoenix.LiveView.Rendered.t()`
      called with `:component_name` and `:site` injected into the assigns
    * `:module_resolver` — `(component_name, site, kind) -> module()` used
      to test whether the dynamic component is actually loaded
    * `:fallback` — adapter to delegate to when the dynamic component is
      unavailable or the renderer is not configured (default
      `MishkaGervaz.UIAdapters.Tailwind`)

  Every callback declared on `MishkaGervaz.Behaviours.UIAdapter` is wired
  identically: try the dynamic renderer, fall back if unavailable. The list
  is taken from `MishkaGervaz.Behaviours.UIAdapter.component_functions/0`,
  so adding a new behaviour callback automatically lights up here.
  """

  @behaviour MishkaGervaz.Behaviours.UIAdapter
  use Phoenix.Component

  @default_site "Global"
  @default_fallback MishkaGervaz.UIAdapters.Tailwind

  for func <- MishkaGervaz.Behaviours.UIAdapter.component_functions() do
    name = Atom.to_string(func)

    @impl true
    def unquote(func)(assigns) do
      render_component(unquote(name), assigns, fn a ->
        fallback(a).unquote(func)(a)
      end)
    end
  end

  @doc """
  Use this module to create a Dynamic adapter with pre-configured options.

  ## Options

  Same as the module-level options — `:site`, `:fallback`,
  `:component_renderer`, `:module_resolver`.

  ## Example

      defmodule MyApp.GervazUIAdapter do
        use MishkaGervaz.UIAdapters.Dynamic,
          site: "Global",
          component_renderer: &MyApp.LiveViewHelpers.component/1,
          module_resolver: &MyApp.Compilers.Helpers.module_name/3,
          fallback: MishkaGervaz.UIAdapters.Tailwind
      end
  """
  defmacro __using__(opts) do
    site = Keyword.get(opts, :site, "Global")
    fallback = Keyword.get(opts, :fallback, MishkaGervaz.UIAdapters.Tailwind)
    component_renderer = Keyword.get(opts, :component_renderer)
    module_resolver = Keyword.get(opts, :module_resolver)

    component_wrappers =
      for func <- MishkaGervaz.Behaviours.UIAdapter.component_functions() do
        quote do
          def unquote(func)(assigns) do
            MishkaGervaz.UIAdapters.Dynamic.unquote(func)(inject_config(assigns))
          end
        end
      end

    quote do
      @behaviour MishkaGervaz.Behaviours.UIAdapter
      use Phoenix.Component

      @site unquote(site)
      @fallback unquote(fallback)
      @component_renderer unquote(component_renderer)
      @module_resolver unquote(module_resolver)

      defp inject_config(assigns) do
        MishkaGervaz.UIAdapters.Dynamic.with_config(assigns,
          site: @site,
          fallback: @fallback,
          component_renderer: @component_renderer,
          module_resolver: @module_resolver
        )
      end

      unquote_splicing(component_wrappers)
    end
  end

  @doc """
  Adds the Dynamic adapter configuration to an assigns map.

  ## Options

    * `:site` (default `"Global"`)
    * `:fallback` (default `MishkaGervaz.UIAdapters.Tailwind`)
    * `:component_renderer` (optional)
    * `:module_resolver` (optional)

  ## Example

      assigns = MishkaGervaz.UIAdapters.Dynamic.with_config(assigns,
        site: "MyApp",
        component_renderer: &MyApp.Runtime.component/1,
        module_resolver: &MyApp.Runtime.module_name/3,
        fallback: MyApp.UIAdapters.Custom
      )
  """
  @spec with_config(map(), keyword()) :: map()
  def with_config(assigns, opts \\ []) do
    site = Keyword.get(opts, :site, @default_site)
    fallback = Keyword.get(opts, :fallback, @default_fallback)
    component_renderer = Keyword.get(opts, :component_renderer)
    module_resolver = Keyword.get(opts, :module_resolver)

    assigns
    |> Map.put(:__site__, site)
    |> Map.put(:__fallback__, fallback)
    |> MishkaGervaz.Helpers.map_put_if_set(:__component_renderer__, component_renderer)
    |> MishkaGervaz.Helpers.map_put_if_set(:__module_resolver__, module_resolver)
  end

  defp render_component(component_name, assigns, fallback_fn) do
    renderer = Map.get(assigns, :__component_renderer__)
    resolver = Map.get(assigns, :__module_resolver__)
    site = Map.get(assigns, :__site__, @default_site)

    if is_function(renderer, 1) and component_available?(resolver, component_name, site) do
      component_assigns =
        assigns
        |> Map.put(:component_name, component_name)
        |> Map.put(:site, site)

      renderer.(component_assigns)
    else
      fallback_fn.(assigns)
    end
  end

  @spec component_available?(function() | nil, String.t(), String.t()) :: boolean()
  defp component_available?(nil, _component_name, _site), do: false

  defp component_available?(resolver, component_name, site) when is_function(resolver, 3) do
    module = resolver.(component_name, site, "Component")
    :erlang.module_loaded(module)
  end

  defp component_available?(_resolver, _component_name, _site), do: false

  defp fallback(assigns), do: Map.get(assigns, :__fallback__, @default_fallback)
end

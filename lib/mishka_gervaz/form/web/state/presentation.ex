defmodule MishkaGervaz.Form.Web.State.Presentation do
  @moduledoc """
  Resolves UI adapter, template, and presentation options for forms.

  ## Overridable Functions

  - `resolve_ui_adapter/1` - Resolve UI adapter module from config
  - `get_ui_adapter_opts/1` - Get UI adapter options
  - `resolve_template/1` - Resolve template module from config
  - `get_theme/1` - Get theme configuration

  ## User Override

      defmodule MyApp.Form.Presentation do
        use MishkaGervaz.Form.Web.State.Presentation

        def resolve_ui_adapter(config) do
          case Map.get(config, :theme) do
            :dark -> MyApp.DarkFormUIAdapter
            _ -> super(config)
          end
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.State.Builder

      @doc """
      Resolves UI adapter module from form config.
      """
      @spec resolve_ui_adapter(map()) :: module()
      def resolve_ui_adapter(config) when is_map(config) do
        config
        |> get_in([:presentation, :ui_adapter])
        |> case do
          nil -> MishkaGervaz.Form.UIAdapters.Tailwind
          :tailwind -> MishkaGervaz.Form.UIAdapters.Tailwind
          module when is_atom(module) -> module
        end
      end

      @spec resolve_ui_adapter(term()) :: module()
      def resolve_ui_adapter(_), do: MishkaGervaz.Form.UIAdapters.Tailwind

      @doc """
      Gets UI adapter options from config.
      """
      @spec get_ui_adapter_opts(map()) :: keyword()
      def get_ui_adapter_opts(config) when is_map(config) do
        config
        |> get_in([:presentation, :ui_adapter_opts])
        |> case do
          nil -> []
          opts -> opts
        end
      end

      @spec get_ui_adapter_opts(term()) :: list()
      def get_ui_adapter_opts(_), do: []

      @doc """
      Resolves template module from config.
      """
      @spec resolve_template(map()) :: module()
      def resolve_template(config) when is_map(config) do
        config
        |> get_in([:presentation, :template])
        |> case do
          nil -> MishkaGervaz.Form.Templates.Standard
          :standard -> MishkaGervaz.Form.Templates.Standard
          module when is_atom(module) -> module
        end
      end

      @spec resolve_template(term()) :: module()
      def resolve_template(_), do: MishkaGervaz.Form.Templates.Standard

      @doc """
      Gets theme configuration from config.
      """
      @spec get_theme(map()) :: map() | nil
      def get_theme(config) when is_map(config) do
        get_in(config, [:presentation, :theme])
      end

      @spec get_theme(term()) :: nil
      def get_theme(_), do: nil

      @doc """
      Gets the features list from config.
      """
      @spec get_features(map()) :: list(atom())
      def get_features(config) when is_map(config) do
        case get_in(config, [:presentation, :features]) do
          :all ->
            [:validation, :uploads, :groups, :wizard, :autosave, :inline_errors]

          list when is_list(list) ->
            list

          _ ->
            [:validation, :uploads, :groups, :wizard, :autosave, :inline_errors]
        end
      end

      @spec get_features(term()) :: list(atom())
      def get_features(_),
        do: [:validation, :uploads, :groups, :wizard, :autosave, :inline_errors]

      defoverridable resolve_ui_adapter: 1,
                     get_ui_adapter_opts: 1,
                     resolve_template: 1,
                     get_theme: 1,
                     get_features: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.Presentation.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.Presentation
end

defmodule MishkaGervaz.Table.Web.State.Presentation do
  @moduledoc """
  Resolves UI adapter, template, and presentation options.

  ## Overridable Functions

  - `resolve_ui_adapter/1` - Resolve UI adapter module from config
  - `get_ui_adapter_opts/1` - Get UI adapter options
  - `resolve_template/1` - Resolve template module from config
  - `get_switchable_templates/1` - Get list of switchable templates
  - `get_template_options/1` - Get template options

  ## User Override

      defmodule MyApp.Table.Presentation do
        use MishkaGervaz.Table.Web.State.Presentation

        def resolve_ui_adapter(config) do
          case Map.get(config, :theme) do
            :dark -> MyApp.DarkUIAdapter
            _ -> super(config)
          end
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.State.Builder

      @doc """
      Resolves UI adapter module from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - The UI adapter module
      """
      @spec resolve_ui_adapter(map()) :: module()
      def resolve_ui_adapter(config) when is_map(config) do
        Map.get(config, :presentation, %{})
        |> Map.get(:ui_adapter, :tailwind)
        |> case do
          :tailwind -> MishkaGervaz.Table.UIAdapters.Tailwind
          :dynamic -> MishkaGervaz.Table.UIAdapters.Dynamic
          module when is_atom(module) -> module
        end
      end

      @spec resolve_ui_adapter(term()) :: module()
      def resolve_ui_adapter(_), do: MishkaGervaz.Table.UIAdapters.Tailwind

      @doc """
      Gets UI adapter options from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A keyword list of UI adapter options
      """
      @spec get_ui_adapter_opts(map()) :: keyword()
      def get_ui_adapter_opts(config) when is_map(config) do
        config
        |> Map.get(:presentation, %{})
        |> Map.get(:ui_adapter_opts, [])
      end

      @spec get_ui_adapter_opts(term()) :: list()
      def get_ui_adapter_opts(_), do: []

      @doc """
      Resolves template module from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - The template module
      """
      @spec resolve_template(map()) :: module()
      def resolve_template(config) when is_map(config) do
        Map.get(config, :presentation, %{})
        |> Map.get(:template, :table)
        |> case do
          :table -> MishkaGervaz.Table.Templates.Table
          :media_gallery -> MishkaGervaz.Table.Templates.MediaGallery
          module when is_atom(module) -> module
        end
      end

      @spec resolve_template(term()) :: module()
      def resolve_template(_), do: MishkaGervaz.Table.Templates.Table

      @doc """
      Gets list of switchable templates from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A list of template modules that can be switched between
      """
      @spec get_switchable_templates(map()) :: list(module())
      def get_switchable_templates(config) when is_map(config) do
        Map.get(config, :presentation, %{})
        |> Map.get(:switchable_templates, [])
        |> Enum.map(fn
          :table -> MishkaGervaz.Table.Templates.Table
          :media_gallery -> MishkaGervaz.Table.Templates.MediaGallery
          module when is_atom(module) -> module
        end)
      end

      @spec get_switchable_templates(term()) :: list()
      def get_switchable_templates(_), do: []

      @doc """
      Gets template options from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A keyword list of template options
      """
      @spec get_template_options(map()) :: keyword()
      def get_template_options(config) when is_map(config) do
        Map.get(config, :presentation, %{}) |> Map.get(:template_options, [])
      end

      @spec get_template_options(term()) :: list()
      def get_template_options(_), do: []

      defoverridable resolve_ui_adapter: 1,
                     get_ui_adapter_opts: 1,
                     resolve_template: 1,
                     get_switchable_templates: 1,
                     get_template_options: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.Presentation.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.Presentation
end

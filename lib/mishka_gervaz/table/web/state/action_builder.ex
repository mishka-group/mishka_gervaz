defmodule MishkaGervaz.Table.Web.State.ActionBuilder do
  @moduledoc """
  Builds row actions, dropdowns, and bulk actions from DSL configuration.

  ## Overridable Functions

  - `build_row_actions/1` - Build row actions from config
  - `build_row_action_dropdowns/1` - Build row action dropdown menus from config
  - `build_row_actions_layout/1` - Build row actions layout (inline/dropdown split) from config
  - `build_bulk_actions/1` - Build bulk actions from config
  - `build_hooks/1` - Build hooks from config

  ## User Override

      defmodule MyApp.Table.ActionBuilder do
        use MishkaGervaz.Table.Web.State.ActionBuilder

        def build_row_actions(config) do
          super(config) ++ [custom_export_action()]
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.State.Builder

      @doc """
      Builds row actions from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A list of row action maps
      """
      @spec build_row_actions(map()) :: list(map())
      def build_row_actions(config) when is_map(config) do
        case Map.get(config, :row_actions) do
          %{actions: actions} when is_list(actions) -> actions
          _ -> []
        end
      end

      @spec build_row_actions(term()) :: list()
      def build_row_actions(_), do: []

      @doc """
      Builds row action dropdown menus from config.

      Each dropdown contains a list of action items and optional separators,
      along with UI configuration (icon, label) for the trigger button.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A list of dropdown maps, each with `:name`, `:items`, and `:ui` keys
      """
      @spec build_row_action_dropdowns(map()) :: list(map())
      def build_row_action_dropdowns(config) when is_map(config) do
        case Map.get(config, :row_actions) do
          %{dropdowns: dropdowns} when is_list(dropdowns) -> dropdowns
          _ -> []
        end
      end

      @spec build_row_action_dropdowns(term()) :: list()
      def build_row_action_dropdowns(_), do: []

      @doc """
      Builds row actions layout configuration from config.

      Controls which actions are rendered inline vs inside dropdown menus.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A map with `:position`, `:sticky`, `:inline`, `:dropdown`,
          and `:auto_collapse_after` keys, or `nil` if not configured
      """
      @spec build_row_actions_layout(map()) :: map() | nil
      def build_row_actions_layout(config) when is_map(config) do
        case Map.get(config, :row_actions) do
          %{layout: layout} when is_map(layout) -> layout
          _ -> nil
        end
      end

      @spec build_row_actions_layout(term()) :: nil
      def build_row_actions_layout(_), do: nil

      @doc """
      Builds bulk actions from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A list of bulk action maps
      """
      @spec build_bulk_actions(map()) :: list(map())
      def build_bulk_actions(config) when is_map(config) do
        case Map.get(config, :bulk_actions) do
          %{enabled: true, actions: actions} when is_list(actions) -> actions
          %{actions: actions} when is_list(actions) -> actions
          _ -> []
        end
      end

      @spec build_bulk_actions(term()) :: list()
      def build_bulk_actions(_), do: []

      @doc """
      Builds hooks from config.

      ## Parameters

        - `config` - The table configuration map

      ## Returns

        - A map of hook configurations
      """
      @spec build_hooks(map()) :: map()
      def build_hooks(config) when is_map(config) do
        case Map.get(config, :hooks) do
          hooks when is_map(hooks) -> hooks
          _ -> %{}
        end
      end

      @spec build_hooks(term()) :: map()
      def build_hooks(_), do: %{}

      defoverridable build_row_actions: 1,
                     build_row_action_dropdowns: 1,
                     build_row_actions_layout: 1,
                     build_bulk_actions: 1,
                     build_hooks: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.ActionBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.ActionBuilder
end

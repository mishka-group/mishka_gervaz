defmodule MishkaGervaz.Table.Web.State do
  @dialyzer :no_opaque

  @moduledoc """
  Single state struct for MishkaGervaz table.

  All table state is held in this struct rather than in separate assigns.

  ## State shape

  State is split into two parts:
  - `static` - Configuration that never changes (same reference for O(1) comparison)
  - Dynamic fields - User interaction state that triggers re-renders

  This separation allows LiveView to skip re-rendering static parts (columns, filters, etc.)
  when only dynamic state (page, filter_values, etc.) changes.

  ## Sub-builders

  State initialization is composed of sub-builders that can be overridden:

  - `ColumnBuilder` - Builds columns from DSL and resource
  - `FilterBuilder` - Builds filters from DSL and resource
  - `ActionBuilder` - Builds row/bulk actions
  - `Presentation` - Resolves UI adapter and templates
  - `UrlSync` - Handles URL state synchronization
  - `Access` - Handles access control

  ## User Override

  Override the entire state module:

      defmodule MyApp.Table.State do
        use MishkaGervaz.Table.Web.State

        def init(id, resource, user) do
          state = super(id, resource, user)
          %{state | custom_field: :value}
        end
      end

  Override specific sub-builders:

      defmodule MyApp.Table.State do
        use MishkaGervaz.Table.Web.State,
          column: MyApp.Table.ColumnBuilder,
          filter: MyApp.Table.FilterBuilder
      end

  Or override via DSL:

      mishka_gervaz do
        table do
          state do
            column MyApp.Table.ColumnBuilder
            filter MyApp.Table.FilterBuilder
          end
        end
      end

  Override entire state module via DSL:

      mishka_gervaz do
        table do
          state module: MyApp.Table.CustomState
        end
      end

  ## Helper Functions

  Helper functions are available in `MishkaGervaz.Table.Web.State.Helpers` and can be
  used when overriding state functions:

      defmodule MyApp.Table.State do
        use MishkaGervaz.Table.Web.State
        alias MishkaGervaz.Table.Web.State.Helpers, as: StateHelpers

        def hydrate_relation_filter_labels(state) do
          # Use helpers in your override
          StateHelpers.hydrate_filter(filter, acc, state)
        end
      end

  See `MishkaGervaz.Table.Web.State.Helpers`,
  `MishkaGervaz.Table.Web.State.ColumnBuilder`,
  `MishkaGervaz.Table.Web.State.FilterBuilder`,
  `MishkaGervaz.Table.Web.State.ActionBuilder`,
  `MishkaGervaz.Table.Web.State.Presentation`,
  `MishkaGervaz.Table.Web.State.UrlSync`,
  `MishkaGervaz.Table.Web.State.Access`,
  `MishkaGervaz.Table.Web.AutoState`,
  `MishkaGervaz.Table.Web.Refresh`,
  `MishkaGervaz.Table.Web.UrlSync`.
  """

  defmodule Static do
    @moduledoc """
    Static table configuration that never changes after initialization.

    Stored as a separate struct so LiveView can skip re-rendering when only
    dynamic state changes. The reference to this struct stays the same across
    all state updates, enabling O(1) equality comparison.
    """

    defstruct [
      :id,
      :resource,
      :stream_name,
      :config,
      :columns,
      :filters,
      :row_actions,
      :row_action_dropdowns,
      :row_actions_layout,
      :bulk_actions,
      :ui_adapter,
      :ui_adapter_opts,
      :switchable_templates,
      :template_options,
      :features,
      :filter_groups,
      :filter_mode,
      :pagination_ui,
      :theme,
      :sortable_columns,
      :sort_field_map,
      :hooks,
      :url_sync_config,
      :page_size,
      :page_size_options,
      :max_page_size,
      :header,
      :footer,
      :notices,
      :keep_loaded_records
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            resource: module(),
            stream_name: atom(),
            config: map(),
            columns: list(map()),
            filters: list(map()),
            row_actions: list(map()),
            row_action_dropdowns: list(map()),
            row_actions_layout: map() | nil,
            bulk_actions: list(map()),
            ui_adapter: module(),
            ui_adapter_opts: keyword(),
            switchable_templates: list(module()),
            template_options: keyword(),
            features: list(atom()),
            filter_groups: list(map()),
            filter_mode: atom(),
            pagination_ui: struct(),
            theme: map() | nil,
            sortable_columns: list(atom()),
            sort_field_map: %{atom() => [atom()]},
            hooks: map(),
            url_sync_config: map() | nil,
            keep_loaded_records: boolean(),
            page_size: pos_integer() | nil,
            page_size_options: [pos_integer()] | nil,
            max_page_size: pos_integer() | nil,
            header: map() | nil,
            footer: map() | nil,
            notices: list(map())
          }
  end

  defstruct [
    :static,
    :current_user,
    :master_user?,
    :preload_aliases,
    :supports_archive,
    :template,
    :loading,
    :loading_type,
    :has_initial_data?,
    :records_result,
    :page,
    :has_more?,
    :total_count,
    :total_pages,
    :filter_values,
    :sort_fields,
    :archive_status,
    :relation_filter_state,
    :selected_ids,
    :excluded_ids,
    :select_all?,
    :expanded_id,
    :expanded_data,
    :path_params,
    :base_path,
    :preserved_params,
    :saved_active_state,
    :saved_archived_state,
    :current_page_size,
    :dismissed_notices,
    :loaded_records
  ]

  @type loading_status :: :initial | :loading | :loaded | :error
  @type loading_type :: :initial | :reset | :more
  @type archive_status :: :active | :archived

  @type t :: %__MODULE__{
          static: Static.t(),
          current_user: map() | nil,
          master_user?: boolean(),
          preload_aliases: %{atom() => atom()},
          supports_archive: boolean(),
          template: module(),
          loading: loading_status(),
          loading_type: loading_type(),
          has_initial_data?: boolean(),
          records_result: struct(),
          page: integer(),
          has_more?: boolean(),
          total_count: integer() | nil,
          total_pages: integer() | nil,
          filter_values: map(),
          sort_fields: list({atom(), :asc | :desc}),
          archive_status: archive_status(),
          relation_filter_state: %{atom() => map()},
          selected_ids: MapSet.t(any()),
          excluded_ids: MapSet.t(any()),
          select_all?: boolean(),
          expanded_id: String.t() | nil,
          expanded_data: struct() | nil,
          path_params: map(),
          base_path: String.t() | nil,
          preserved_params: map(),
          saved_active_state: map() | nil,
          saved_archived_state: map() | nil,
          current_page_size: pos_integer() | nil,
          dismissed_notices: MapSet.t(),
          loaded_records: list()
        }

  @spec init(String.t(), module(), map() | nil) :: t()
  defdelegate init(id, resource, current_user), to: __MODULE__.Default

  @spec default_init(String.t(), module(), map() | nil) :: t()
  defdelegate default_init(id, resource, current_user), to: __MODULE__.Default

  @spec update(t(), keyword() | map()) :: t()
  defdelegate update(state, updates), to: __MODULE__.Default

  @spec apply_url_state(t(), map() | nil) :: t()
  defdelegate apply_url_state(state, url_state), to: __MODULE__.Default

  @doc "Hydrate relation filter state with labels for selected values from URL"
  @spec hydrate_relation_filter_labels(t()) :: t()
  defdelegate hydrate_relation_filter_labels(state), to: __MODULE__.Default

  @spec bidirectional_url_sync?(t()) :: boolean()
  defdelegate bidirectional_url_sync?(state), to: __MODULE__.Default

  @spec switch_template(t(), atom()) :: {:ok, t()} | {:error, :template_not_allowed}
  @doc """
  Applies a mount's own presentation choices over the resource's — see the `__using__` version.
  """
  defdelegate apply_presentation(state, assigns), to: __MODULE__.Default

  defdelegate switch_template(state, template), to: __MODULE__.Default

  @spec template_switching_enabled?(t()) :: boolean()
  defdelegate template_switching_enabled?(state), to: __MODULE__.Default

  @spec can_modify_record?(t(), map()) :: boolean()
  defdelegate can_modify_record?(state, record), to: __MODULE__.Default

  @spec record_visible?(t(), map()) :: boolean()
  defdelegate record_visible?(state, record), to: __MODULE__.Default

  @spec get_action(t(), atom()) :: atom()
  defdelegate get_action(state, action_type), to: __MODULE__.Default

  @spec get_preloads(t()) :: list(atom())
  defdelegate get_preloads(state), to: __MODULE__.Default

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias MishkaGervaz.Table.Web.State
      alias MishkaGervaz.Table.Web.State.Static
      alias MishkaGervaz.Table.Web.State.Helpers, as: StateHelpers
      alias MishkaGervaz.Resource.Info.Table, as: Info
      alias Phoenix.LiveView.AsyncResult

      @__column_builder__ Keyword.get(
                            opts,
                            :column,
                            MishkaGervaz.Table.Web.State.ColumnBuilder.Default
                          )
      @__filter_builder__ Keyword.get(
                            opts,
                            :filter,
                            MishkaGervaz.Table.Web.State.FilterBuilder.Default
                          )
      @__action_builder__ Keyword.get(
                            opts,
                            :action,
                            MishkaGervaz.Table.Web.State.ActionBuilder.Default
                          )
      @__presentation__ Keyword.get(
                          opts,
                          :presentation,
                          MishkaGervaz.Table.Web.State.Presentation.Default
                        )
      @__url_sync__ Keyword.get(
                      opts,
                      :url_sync,
                      MishkaGervaz.Table.Web.State.UrlSync.Default
                    )
      @__access__ Keyword.get(
                    opts,
                    :access,
                    MishkaGervaz.Table.Web.State.Access.Default
                  )

      @spec column_builder() :: module()
      def column_builder, do: @__column_builder__

      @spec filter_builder() :: module()
      def filter_builder, do: @__filter_builder__

      @spec action_builder() :: module()
      def action_builder, do: @__action_builder__

      @spec presentation() :: module()
      def presentation, do: @__presentation__

      @spec url_sync() :: module()
      def url_sync, do: @__url_sync__

      @spec access() :: module()
      def access, do: @__access__

      @spec init(String.t(), module(), map() | nil) :: State.t()
      def init(id, resource, current_user) do
        dsl_state = Info.state(resource)

        case Map.get(dsl_state, :module) do
          nil ->
            do_init(id, resource, current_user, dsl_state)

          custom_module ->
            custom_module.init(id, resource, current_user)
        end
      end

      @spec default_init(String.t(), module(), map() | nil) :: State.t()
      def default_init(id, resource, current_user) do
        dsl_state = Info.state(resource) |> Map.delete(:module)
        do_init(id, resource, current_user, dsl_state)
      end

      @spec do_init(String.t(), module(), map() | nil, map()) :: State.t()
      defp do_init(id, resource, current_user, dsl_state) do
        config = Info.config(resource)

        column_mod = Map.get(dsl_state, :column, column_builder())
        filter_mod = Map.get(dsl_state, :filter, filter_builder())
        action_mod = Map.get(dsl_state, :action, action_builder())
        presentation_mod = Map.get(dsl_state, :presentation, presentation())
        access_mod = Map.get(dsl_state, :access, access())

        master_user? = access_mod.master_user?(current_user)
        preload_aliases = Info.preload_aliases(resource, master_user?)
        columns = column_mod.build(config, resource)
        filters = filter_mod.build(config, resource, current_user)

        base_stream_name =
          Info.stream_name(resource) || StateHelpers.generate_stream_name(resource)

        stream_name = :"#{id}_#{base_stream_name}"
        template = presentation_mod.resolve_template(config)

        static = %Static{
          id: id,
          resource: resource,
          stream_name: stream_name,
          config: config,
          columns: columns,
          filters: filters,
          row_actions: action_mod.build_row_actions(config),
          row_action_dropdowns: action_mod.build_row_action_dropdowns(config),
          row_actions_layout: action_mod.build_row_actions_layout(config),
          bulk_actions: action_mod.build_bulk_actions(config),
          ui_adapter: presentation_mod.resolve_ui_adapter(config),
          ui_adapter_opts: presentation_mod.get_ui_adapter_opts(config),
          switchable_templates: presentation_mod.get_switchable_templates(config),
          template_options: presentation_mod.get_template_options(config),
          features: StateHelpers.get_features(config, template),
          filter_groups: StateHelpers.get_filter_groups(config),
          filter_mode: StateHelpers.get_filter_mode(config),
          pagination_ui: StateHelpers.get_pagination_ui(config),
          theme: get_in(config, [:presentation, :theme]),
          sortable_columns: StateHelpers.get_sortable_columns(columns),
          sort_field_map: StateHelpers.build_sort_field_map(columns),
          hooks: action_mod.build_hooks(config),
          url_sync_config: get_in(config, [:url_sync]),
          page_size: StateHelpers.get_page_size(config),
          page_size_options: StateHelpers.get_page_size_options(config),
          max_page_size: StateHelpers.get_max_page_size(config),
          header: StateHelpers.get_layout_header(config),
          footer: StateHelpers.get_layout_footer(config),
          notices: StateHelpers.get_layout_notices(config),
          keep_loaded_records: get_in(config, [:presentation, :keep_loaded_records]) == true
        }

        %State{
          static: static,
          current_user: current_user,
          master_user?: master_user?,
          preload_aliases: preload_aliases,
          supports_archive: StateHelpers.get_supports_archive(config, master_user?),
          template: template,
          loading: :initial,
          loading_type: :initial,
          has_initial_data?: false,
          records_result: AsyncResult.loading(),
          page: 1,
          has_more?: false,
          total_count: nil,
          total_pages: nil,
          filter_values: filter_mod.build_initial_values(filters),
          sort_fields: StateHelpers.get_default_sort(config, columns),
          archive_status: :active,
          relation_filter_state: %{},
          selected_ids: MapSet.new(),
          excluded_ids: MapSet.new(),
          select_all?: false,
          expanded_id: nil,
          expanded_data: nil,
          path_params: %{},
          base_path: nil,
          preserved_params: %{},
          saved_active_state: nil,
          saved_archived_state: nil,
          current_page_size: nil,
          dismissed_notices: MapSet.new(),
          loaded_records: []
        }
      end

      @spec update(State.t(), keyword() | map()) :: State.t()
      def update(%State{} = state, updates), do: struct(state, updates)

      @spec apply_url_state(State.t(), map() | nil) :: State.t()
      def apply_url_state(%State{static: %{resource: resource}} = state, url_state) do
        StateHelpers.resolve_url_sync(resource, url_sync()).apply_url_state(state, url_state)
      end

      @doc """
      Hydrates relation filter state with human-readable labels for selected values.

      When state is restored from URL (e.g., `?author_id=abc-123`), we only have IDs.
      This function queries the database to resolve those IDs to `{label, value}` tuples
      so the UI can display proper labels (e.g., "John Smith") instead of raw UUIDs.

      Uses the DSL-configured RelationLoader module for database queries.

      ## Example

          # Before: filter_values has IDs but no labels
          state.filter_values = %{author_id: "abc-123"}
          state.relation_filter_state = %{}

          # After: relation_filter_state has resolved labels
          state.relation_filter_state = %{
            author_id: %{
              selected_options: [{"John Smith", "abc-123"}],
              options: [],
              has_more?: false,
              page: 1
            }
          }
      """
      @spec hydrate_relation_filter_labels(State.t()) :: State.t()
      def hydrate_relation_filter_labels(%State{} = state) do
        new_relation_filter_state =
          state.static.filters
          |> List.wrap()
          |> Enum.filter(&(&1.type == :relation))
          |> Enum.reduce(
            state.relation_filter_state || %{},
            &StateHelpers.hydrate_filter(&1, &2, state)
          )

        %{state | relation_filter_state: new_relation_filter_state}
      end

      @spec bidirectional_url_sync?(State.t()) :: boolean()
      def bidirectional_url_sync?(%State{static: %{resource: resource}} = state) do
        StateHelpers.resolve_url_sync(resource, url_sync()).bidirectional?(state)
      end

      @doc """
      Applies one mount's own presentation choices over the ones the resource declared.

      Three keys, all optional and all ignored when absent, so a mount that passes none is left
      unchanged:

        * `:template` — the template this mount starts with. A module, or the `name/0` of one the
          resource already knows.
        * `:switchable_templates` — what the switcher offers on this mount. An empty list, or one
          entry, turns the switcher off here (`template_switching_enabled?/1` asks for more than
          one); the resource's own list is untouched everywhere else.
        * `:url_sync` — `false` stops this mount pushing its state into the address bar. The
          `url_state` it was given still applies, `path_params` included; only the patch back is
          dropped. Every other mount keeps the resource's own setting.

      Call this at init only, since the reader may switch templates afterwards.
      """
      @spec apply_presentation(State.t(), map()) :: State.t()
      def apply_presentation(state, assigns) when is_map(assigns) do
        state
        |> override_switchables(Map.get(assigns, :switchable_templates))
        |> override_template(Map.get(assigns, :template))
        |> override_url_sync(Map.get(assigns, :url_sync))
      end

      def apply_presentation(state, _assigns), do: state

      defp override_url_sync(%{static: %{url_sync_config: config} = static} = state, false)
           when is_map(config),
           do: %{state | static: %{static | url_sync_config: Map.put(config, :enabled, false)}}

      defp override_url_sync(state, _other), do: state

      defp override_switchables(state, nil), do: state

      defp override_switchables(state, templates) when is_list(templates),
        do: %{state | static: %{state.static | switchable_templates: templates}}

      defp override_switchables(state, _other), do: state

      defp override_template(state, nil), do: state

      defp override_template(state, template) when is_atom(template) do
        cond do
          template_module?(template) -> %{state | template: template}
          found = by_name(state, template) -> %{state | template: found}
          true -> state
        end
      end

      defp override_template(state, _other), do: state

      defp template_module?(module),
        do: Code.ensure_loaded?(module) and function_exported?(module, :render, 1)

      defp by_name(%State{static: %{switchable_templates: templates}}, name) do
        Enum.find(templates, &(&1.name() == name))
      end

      @spec switch_template(State.t(), atom()) ::
              {:ok, State.t()} | {:error, :template_not_allowed}
      def switch_template(%State{static: %{switchable_templates: []}} = _state, _template) do
        {:error, :template_not_allowed}
      end

      def switch_template(
            %State{static: %{switchable_templates: templates}} = state,
            template_name
          )
          when is_atom(template_name) do
        Enum.find(templates, &(&1 == template_name or &1.name() == template_name))
        |> case do
          nil -> {:error, :template_not_allowed}
          template -> {:ok, %{state | template: template}}
        end
      end

      @spec template_switching_enabled?(State.t()) :: boolean()
      def template_switching_enabled?(%State{static: %{switchable_templates: templates}}) do
        length(templates) > 1
      end

      @spec can_modify_record?(State.t(), map()) :: boolean()
      def can_modify_record?(
            %State{static: %{resource: resource}, master_user?: master_user?, current_user: user},
            record
          ) do
        StateHelpers.resolve_access(resource, access()).can_modify_record?(
          master_user?,
          user,
          record
        )
      end

      @spec record_visible?(State.t(), map()) :: boolean()
      def record_visible?(
            %State{
              static: %{resource: resource, config: config},
              master_user?: master_user?,
              current_user: user
            },
            record
          ) do
        StateHelpers.resolve_access(resource, access()).record_visible?(
          master_user?,
          config,
          user,
          record
        )
      end

      @spec get_action(State.t(), atom()) :: atom()
      def get_action(
            %State{static: %{resource: resource}, master_user?: master_user?},
            action_type
          ) do
        StateHelpers.resolve_access(resource, access()).get_action(
          resource,
          action_type,
          master_user?
        )
      end

      @spec get_preloads(State.t()) :: list(atom())
      def get_preloads(%State{static: %{resource: resource}, master_user?: master_user?}) do
        StateHelpers.resolve_access(resource, access()).get_preloads(resource, master_user?)
      end

      defoverridable column_builder: 0,
                     filter_builder: 0,
                     action_builder: 0,
                     presentation: 0,
                     url_sync: 0,
                     access: 0,
                     init: 3,
                     default_init: 3,
                     update: 2,
                     apply_url_state: 2,
                     hydrate_relation_filter_labels: 1,
                     bidirectional_url_sync?: 1,
                     apply_presentation: 2,
                     switch_template: 2,
                     template_switching_enabled?: 1,
                     can_modify_record?: 2,
                     record_visible?: 2,
                     get_action: 2,
                     get_preloads: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.Default do
  @moduledoc false
  @dialyzer :no_opaque
  use MishkaGervaz.Table.Web.State
end

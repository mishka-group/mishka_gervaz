defmodule MishkaGervaz.Table.Transformers.BuildRuntimeConfig do
  @moduledoc """
  Builds the final runtime configuration from the DSL state.

  This transformer runs last and compiles the DSL configuration into
  a map structure that can be efficiently accessed at runtime by the
  LiveComponent.

  The compiled configuration is persisted as `:mishka_gervaz_config`
  and can be retrieved via `MishkaGervaz.Resource.Info.Table.config/1`.

  ## Section Behavior

  - Sections return `nil` when not defined: `source`, `columns`, `filters`,
    `row_actions`, `row`, `bulk_actions`, `hooks`
  - Sections inherit from domain first, then use defaults: `presentation`,
    `refresh`, `url_sync`, `realtime`
  - Sections always return defaults (never nil): `pagination`, `empty_state`,
    `error_state`

  ## Multi-tenancy

  For non-multi-tenant resources, action tuples use only the second (tenant) action,
  since there's no master/tenant distinction.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  import MishkaGervaz.Table.Transformers.Helpers

  alias MishkaGervaz.Table.Entities.{
    Column,
    Filter,
    FilterGroup,
    RowAction,
    RowActionDropdown,
    DropdownSeparator,
    RowOverride,
    BulkAction,
    Realtime,
    Pagination,
    EmptyState,
    ErrorState,
    DataLoader,
    Events
  }

  @table_path [:mishka_gervaz, :table]

  @impl true
  def after?(MishkaGervaz.Table.Transformers.ResolveColumns), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)
    domain_defaults = get_domain_defaults(module)
    domain_config = get_domain_config(module)
    multitenancy = build_multitenancy(module)
    has_archival? = has_extension?(module, AshArchival.Resource)

    config = %{
      identity: build_identity(dsl_state),
      source: build_source(dsl_state, domain_defaults, multitenancy, has_archival?),
      multitenancy: multitenancy,
      realtime: build_realtime(dsl_state, domain_defaults),
      columns: build_columns(dsl_state, module),
      filters: build_filters(dsl_state, module),
      filter_groups: build_filter_groups(dsl_state),
      row_actions: build_row_actions(dsl_state),
      row: build_row(dsl_state),
      bulk_actions: build_bulk_actions(dsl_state),
      pagination: build_pagination(dsl_state, domain_defaults),
      empty_state: build_empty_state(dsl_state),
      error_state: build_error_state(dsl_state),
      presentation: build_presentation(dsl_state, module, domain_config),
      refresh: build_refresh(dsl_state, domain_defaults),
      url_sync: build_url_sync(dsl_state, domain_defaults),
      hooks: build_hooks(dsl_state),
      data_loader: build_data_loader(dsl_state),
      events: build_events(dsl_state),
      detected_preloads:
        Transformer.get_persisted(dsl_state, :mishka_gervaz_detected_preloads, []),
      column_order: Transformer.get_persisted(dsl_state, :mishka_gervaz_column_order, [])
    }

    {:ok, Transformer.persist(dsl_state, :mishka_gervaz_config, config)}
  end

  defp get_domain_defaults(module) do
    case get_domain_config(module) do
      %{table: table} -> table
      _ -> %{}
    end
  end

  defp build_multitenancy(module) do
    strategy = Ash.Resource.Info.multitenancy_strategy(module)

    %{
      enabled: strategy != nil,
      strategy: strategy,
      attribute: Ash.Resource.Info.multitenancy_attribute(module),
      global?: Ash.Resource.Info.multitenancy_global?(module)
    }
  end

  defp resolve_action({_master, _tenant} = tuple, _multitenancy), do: tuple
  defp resolve_action(action, _multitenancy) when is_atom(action), do: action

  defp build_identity(dsl_state) do
    path = @table_path ++ [:identity]

    %{
      name: get_opt(dsl_state, path, :name),
      route: get_opt(dsl_state, path, :route),
      stream_name: get_opt(dsl_state, path, :stream_name)
    }
  end

  defp build_source(dsl_state, domain_defaults, multitenancy, has_archival?) do
    actions_path = @table_path ++ [:source, :actions]
    preload_path = @table_path ++ [:source, :preload]
    source_path = @table_path ++ [:source]

    domain_actions = domain_defaults[:actions] || %{}

    dsl_read = get_opt(dsl_state, actions_path, :read)
    dsl_get = get_opt(dsl_state, actions_path, :get)
    dsl_destroy = get_opt(dsl_state, actions_path, :destroy)

    read =
      dsl_read || domain_actions[:read] ||
        default_action(:read, multitenancy)

    get =
      dsl_get || domain_actions[:get] ||
        default_action(:get, multitenancy)

    destroy =
      dsl_destroy || domain_actions[:destroy] ||
        default_action(:destroy, multitenancy)

    %{
      actor_key:
        get_opt(dsl_state, source_path, :actor_key) || domain_defaults[:actor_key] ||
          :current_user,
      master_check:
        get_opt(dsl_state, source_path, :master_check) || domain_defaults[:master_check],
      actions: %{
        read: resolve_action(read, multitenancy),
        get: resolve_action(get, multitenancy),
        destroy: resolve_action(destroy, multitenancy)
      },
      preload: %{
        always: get_opt(dsl_state, preload_path, :always, []),
        master: get_opt(dsl_state, preload_path, :master, []),
        tenant: get_opt(dsl_state, preload_path, :tenant, [])
      },
      archive: build_archive(dsl_state, multitenancy, has_archival?)
    }
  end

  defp default_action(:read, %{enabled: true}), do: {:master_read, :tenant_read}
  defp default_action(:read, _), do: :read
  defp default_action(:get, %{enabled: true}), do: {:master_get, :get}
  defp default_action(:get, _), do: :get
  defp default_action(:destroy, %{enabled: true}), do: {:master_destroy, :destroy}
  defp default_action(:destroy, _), do: :destroy

  defp build_archive(dsl_state, multitenancy, has_archival?) do
    path = @table_path ++ [:source, :archive]
    opts = [:enabled, :restricted, :display, :read_action]
    section_defined? = any_set?(Enum.map(opts, &get_opt(dsl_state, path, &1)))

    cond do
      not section_defined? and not has_archival? -> nil
      not section_defined? and has_archival? -> archive_defaults(multitenancy)
      true -> archive_config(dsl_state, multitenancy)
    end
  end

  defp archive_defaults(multitenancy) do
    %{
      enabled: true,
      restricted: false,
      visible: true,
      actions: %{
        read: resolve_action({:master_archived, :archived}, multitenancy),
        get: resolve_action({:master_get_archived, :get_archived}, multitenancy),
        restore: resolve_action({:master_unarchive, :unarchive}, multitenancy),
        destroy: resolve_action({:master_permanent_destroy, :permanent_destroy}, multitenancy)
      }
    }
  end

  defp archive_config(dsl_state, multitenancy) do
    path = @table_path ++ [:source, :archive]

    read = get_opt(dsl_state, path, :read_action)
    get = get_opt(dsl_state, path, :get_action)
    restore = get_opt(dsl_state, path, :restore_action)
    destroy = get_opt(dsl_state, path, :destroy_action)

    %{
      enabled: get_opt(dsl_state, path, :enabled, true),
      restricted: get_opt(dsl_state, path, :restricted, false),
      visible: get_opt(dsl_state, path, :visible, true),
      actions: %{
        read: resolve_action(read || {:master_archived, :archived}, multitenancy),
        get: resolve_action(get || {:master_get_archived, :get_archived}, multitenancy),
        restore: resolve_action(restore || {:master_unarchive, :unarchive}, multitenancy),
        destroy:
          resolve_action(destroy || {:master_permanent_destroy, :permanent_destroy}, multitenancy)
      }
    }
  end

  defp build_realtime(dsl_state, domain_defaults) do
    defaults = domain_defaults[:realtime] || %{}

    case find_entity(dsl_state, @table_path, Realtime) do
      nil ->
        %{
          enabled: default_if_nil(defaults[:enabled], false),
          pubsub: defaults[:pubsub],
          prefix: nil,
          visible: nil
        }

      entity ->
        %{
          enabled: default_if_nil(entity.enabled, default_if_nil(defaults[:enabled], true)),
          pubsub: entity.pubsub || defaults[:pubsub],
          prefix: entity.prefix,
          visible: entity.visible
        }
    end
  end

  defp build_columns(dsl_state, module) do
    path = @table_path ++ [:columns]
    entities = get_entities(dsl_state, path)
    columns = filter_by_type(entities, Column)

    order_opt = get_opt(dsl_state, path, :column_order)
    default_sort = get_opt(dsl_state, path, :default_sort)

    if columns != [] or order_opt != nil or default_sort != nil do
      ash_attrs = get_ash_attributes(module)

      %{
        list: Enum.map(columns, &column_to_map(&1, ash_attrs)),
        order: Transformer.get_persisted(dsl_state, :mishka_gervaz_column_order, []),
        default_sort: default_sort
      }
    else
      nil
    end
  end

  defp get_ash_attributes(module) do
    module
    |> Ash.Resource.Info.attributes()
    |> Map.new(
      &{&1.name, %{sortable: &1.sortable?, public: &1.public?, filterable: &1.filterable?}}
    )
  rescue
    _ -> %{}
  end

  defp column_to_map(col, ash_attrs) do
    attr = Map.get(ash_attrs, col.name, %{})

    %{
      name: col.name,
      source: col.source,
      sortable: default_if_nil(col.sortable, default_if_nil(attr[:sortable], false)),
      searchable: default_if_nil(col.searchable, false),
      filterable: default_if_nil(col.filterable, default_if_nil(attr[:filterable], false)),
      visible: default_if_nil(col.visible, default_if_nil(attr[:public], true)),
      position: col.position,
      export: col.export,
      export_as: col.export_as,
      default: col.default,
      separator: col.separator,
      static: col.static,
      requires: col.requires,
      sort_field: Map.get(col, :sort_field, []),
      format: col.format,
      render: col.render,
      label: col.label,
      type_module: col.type_module,
      ui: maybe_ui(col.ui, &column_ui_to_map/1, &has_column_ui_values?/1)
    }
  end

  defp has_column_ui_values?(%Column.Ui{} = ui) do
    any_set?([
      ui.label,
      ui.type,
      ui.width,
      ui.min_width,
      ui.max_width,
      ui.class,
      ui.header_class,
      ui.align
    ]) or
      ui.extra != %{}
  end

  defp has_column_ui_values?(_), do: false

  defp column_ui_to_map(%Column.Ui{} = ui) do
    %{
      label: ui.label,
      type: ui.type,
      width: ui.width,
      min_width: ui.min_width,
      max_width: ui.max_width,
      align: ui.align,
      class: ui.class,
      header_class: ui.header_class,
      extra: ui.extra
    }
  end

  defp build_filters(dsl_state, module) do
    path = @table_path ++ [:filters]
    entities = get_entities(dsl_state, path)
    filters = filter_by_type(entities, Filter)

    if filters != [] do
      ash_attrs = get_ash_attrs_for_filters(dsl_state)

      %{
        list: Enum.map(filters, &filter_to_map(&1, ash_attrs, module))
      }
    else
      nil
    end
  end

  defp build_filter_groups(dsl_state) do
    path = @table_path ++ [:filter_groups]
    entities = get_entities(dsl_state, path)
    groups = filter_by_type(entities, FilterGroup)

    if groups != [] do
      Enum.map(groups, &filter_group_to_map/1)
    else
      []
    end
  end

  defp filter_group_to_map(%FilterGroup{} = group) do
    ui = extract_nested_entity(group.ui, FilterGroup.Ui)

    %{
      name: group.name,
      filters: group.filters,
      collapsed: group.collapsed,
      collapsible: group.collapsible,
      visible: group.visible,
      restricted: default_if_nil(group.restricted, false),
      position: group.position,
      ui: maybe_ui(ui, &filter_group_ui_to_map/1, &has_filter_group_ui_values?/1)
    }
  end

  defp filter_group_ui_to_map(ui) do
    %{
      label: ui.label,
      icon: ui.icon,
      description: ui.description,
      class: ui.class,
      header_class: ui.header_class,
      columns: ui.columns,
      extra: ui.extra
    }
  end

  defp has_filter_group_ui_values?(ui) do
    ui.label != nil or ui.icon != nil or ui.description != nil or
      ui.class != nil or ui.header_class != nil or ui.columns != nil or
      ui.extra != %{}
  end

  defp get_ash_attrs_for_filters(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:attributes])
    |> Map.new(&{&1.name, %{type: &1.type, constraints: &1.constraints}})
  rescue
    _ -> %{}
  end

  defp filter_to_map(filter, ash_attrs, table_resource) do
    ui = extract_nested_entity(filter.ui, Filter.Ui)
    options = resolve_filter_options(filter, ash_attrs)
    id_type = resolve_relation_id_type(filter, table_resource)

    %{
      name: filter.name,
      type: filter.type,
      source: filter.source,
      fields: filter.fields,
      depends_on: filter.depends_on,
      visible: filter.visible,
      restricted: default_if_nil(filter.restricted, false),
      options: options,
      default: filter.default,
      presets: filter.presets,
      display_field: filter.display_field,
      search_field: filter.search_field,
      include_nil: filter.include_nil,
      min: filter.min,
      max: filter.max,
      min_chars: filter.min_chars,
      virtual: filter.virtual,
      resource: filter.resource,
      load_action: filter.load_action || :read,
      load: filter.load,
      apply: filter.apply,
      mode: filter.mode || :static,
      page_size: filter.page_size || 20,
      type_module: filter.type_module,
      id_type: id_type,
      ui: maybe_ui(ui, &filter_ui_to_map/1, &has_filter_ui_values?/1),
      preload: filter.preload
    }
  end

  defp resolve_relation_id_type(%{type: :relation} = filter, table_resource) do
    related_resource = resolve_related_resource(filter, table_resource)

    if related_resource do
      get_primary_key_type(related_resource)
    else
      :uuid
    end
  end

  defp resolve_relation_id_type(_, _), do: nil

  defp resolve_related_resource(%{resource: resource}, _) when not is_nil(resource), do: resource

  defp resolve_related_resource(%{name: name, source: source}, table_resource)
       when not is_nil(table_resource) do
    field_name = source || name

    table_resource
    |> Ash.Resource.Info.relationships()
    |> Enum.find(&(&1.source_attribute == field_name))
    |> case do
      %{destination: dest} -> dest
      nil -> nil
    end
  rescue
    _ -> nil
  end

  defp resolve_related_resource(_, _), do: nil

  defp get_primary_key_type(resource) do
    case Ash.Resource.Info.primary_key(resource) do
      [pk_field | _] ->
        case Ash.Resource.Info.attribute(resource, pk_field) do
          %{type: type} -> normalize_id_type(type)
          _ -> :uuid
        end

      _ ->
        :uuid
    end
  rescue
    _ -> :uuid
  end

  defp normalize_id_type(type) when is_atom(type) do
    type_string = Atom.to_string(type)

    cond do
      type == :uuid or type == Ash.Type.UUID ->
        :uuid

      type == :integer or type == Ash.Type.Integer ->
        :integer

      type == :string or type == Ash.Type.String ->
        :string

      String.contains?(type_string, "UUIDv7") or String.contains?(type_string, "UUID7") ->
        :uuid_v7

      String.contains?(type_string, "UUID") ->
        :uuid

      String.contains?(type_string, "Integer") ->
        :integer

      true ->
        :uuid
    end
  end

  defp normalize_id_type(_), do: :uuid

  defp resolve_filter_options(%{options: opts}, _) when not is_nil(opts), do: opts

  defp resolve_filter_options(%{type: type, source: src, name: name}, ash_attrs)
       when type in [:select, :multi_select] do
    attr_name = src || name

    case ash_attrs[attr_name] do
      %{constraints: constraints} when is_list(constraints) ->
        case Keyword.get(constraints, :one_of) do
          [_ | _] = values -> Enum.map(values, &{MishkaGervaz.Helpers.humanize(&1), &1})
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp resolve_filter_options(_, _), do: nil

  defp has_filter_ui_values?(%Filter.Ui{} = ui) do
    any_set?([ui.label, ui.placeholder, ui.icon]) or
      ui.prompt != "Select..." or not is_nil(ui.disabled_prompt) or
      ui.debounce != 300 or ui.extra != %{}
  end

  defp has_filter_ui_values?(_), do: false

  defp filter_ui_to_map(%Filter.Ui{} = ui) do
    %{
      label: ui.label,
      placeholder: ui.placeholder,
      prompt: ui.prompt,
      disabled_prompt: ui.disabled_prompt,
      icon: ui.icon,
      debounce: ui.debounce,
      extra: ui.extra
    }
  end

  defp build_row_actions(dsl_state) do
    path = @table_path ++ [:row_actions]
    layout_path = path ++ [:actions_layout]
    entities = get_entities(dsl_state, path)

    actions = filter_by_type(entities, RowAction)
    dropdowns = filter_by_type(entities, RowActionDropdown)
    layout_pos = get_opt(dsl_state, layout_path, :position)

    if actions != [] or dropdowns != [] or layout_pos != nil do
      %{
        actions: Enum.map(actions, &row_action_to_map/1),
        dropdowns: Enum.map(dropdowns, &dropdown_to_map/1),
        layout: %{
          position: get_opt(dsl_state, layout_path, :position) || :end,
          sticky: default_if_nil(get_opt(dsl_state, layout_path, :sticky), true),
          inline: get_opt(dsl_state, layout_path, :inline) || [],
          dropdown: get_opt(dsl_state, layout_path, :dropdown) || [],
          auto_collapse_after: get_opt(dsl_state, layout_path, :auto_collapse_after)
        }
      }
    else
      nil
    end
  end

  defp row_action_to_map(action) do
    ui = extract_nested_entity(action.ui, RowAction.Ui)

    %{
      name: action.name,
      type: action.type,
      path: action.path,
      event: action.event,
      action: action.action,
      payload: action.payload,
      confirm: action.confirm,
      restricted: default_if_nil(action.restricted, false),
      visible: action.visible,
      render: action.render,
      type_module: action.type_module,
      ui: maybe_ui(ui, &action_ui_to_map/1, &has_action_ui_values?/1)
    }
  end

  defp dropdown_to_map(dropdown) do
    ui = extract_nested_entity(dropdown.ui, RowAction.Ui)

    items =
      Enum.map(dropdown.items, fn
        %RowAction{} = action -> row_action_to_map(action)
        %DropdownSeparator{} = sep -> %{type: :separator, label: sep.label}
      end)

    %{name: dropdown.name, items: items, ui: ui && action_ui_to_map(ui)}
  end

  defp has_action_ui_values?(%RowAction.Ui{} = ui),
    do: any_set?([ui.label, ui.icon, ui.class]) or ui.extra != %{}

  defp has_action_ui_values?(_), do: false

  defp action_ui_to_map(%RowAction.Ui{} = ui),
    do: %{label: ui.label, icon: ui.icon, class: ui.class, extra: ui.extra}

  defp build_row(dsl_state) do
    path = @table_path ++ [:row]
    class_path = path ++ [:class]
    entities = get_entities(dsl_state, path)
    overrides = filter_by_type(entities, RowOverride)

    event = get_opt(dsl_state, path, :event)
    payload = get_opt(dsl_state, path, :payload)
    selectable = get_opt(dsl_state, path, :selectable)
    class_possible = get_opt(dsl_state, class_path, :possible)
    class_apply = get_opt(dsl_state, class_path, :apply)

    if overrides != [] or any_set?([event, selectable, class_possible, class_apply]) do
      class_section =
        if class_possible != nil or class_apply != nil,
          do: %{possible: class_possible || [], apply: class_apply},
          else: nil

      %{
        class: class_section,
        overrides: Enum.map(overrides, &row_override_to_map/1),
        event: event,
        payload: payload,
        selectable: default_if_nil(selectable, false)
      }
    else
      nil
    end
  end

  defp row_override_to_map(override) do
    %{
      condition: override.condition,
      render: override.render,
      component: override.component
    }
  end

  defp build_bulk_actions(dsl_state) do
    path = @table_path ++ [:bulk_actions]
    entities = get_entities(dsl_state, path)
    actions = filter_by_type(entities, BulkAction)
    enabled = get_opt(dsl_state, path, :enabled)

    if actions != [] or enabled != nil do
      %{
        enabled: default_if_nil(enabled, true),
        actions: Enum.map(actions, &bulk_action_to_map/1)
      }
    else
      nil
    end
  end

  defp bulk_action_to_map(action) do
    %{
      name: action.name,
      confirm: action.confirm,
      event: action.event,
      payload: action.payload,
      restricted: default_if_nil(action.restricted, false),
      visible: action.visible,
      handler: default_if_nil(action.handler, :parent),
      ui: maybe_ui(action.ui, &bulk_ui_to_map/1, &has_bulk_ui_values?/1)
    }
  end

  defp has_bulk_ui_values?(%BulkAction.Ui{} = ui),
    do: any_set?([ui.label, ui.icon, ui.class]) or ui.extra != %{}

  defp has_bulk_ui_values?(_), do: false

  defp bulk_ui_to_map(%BulkAction.Ui{} = ui),
    do: %{label: ui.label, icon: ui.icon, class: ui.class, extra: ui.extra}

  defp build_pagination(dsl_state, domain_defaults) do
    domain = domain_defaults[:pagination] || %{}
    resource = find_entity(dsl_state, @table_path, Pagination)

    page_size = (resource && resource.page_size) || domain[:page_size]
    type = (resource && resource.type) || domain[:type]

    if is_nil(page_size) and is_nil(type) and is_nil(resource) do
      nil
    else
      ui = (resource && resource.ui) || struct(Pagination.Ui)

      %{
        type: type || :numbered,
        page_size: page_size || 20,
        page_size_options:
          (resource && resource.page_size_options) || domain[:page_size_options] || [20, 50, 100],
        ui: pagination_ui_to_map(ui)
      }
    end
  end

  defp pagination_ui_to_map(ui) do
    %{
      load_more_label: ui.load_more_label,
      loading_text: ui.loading_text,
      show_total: ui.show_total,
      prev_label: ui.prev_label,
      next_label: ui.next_label,
      first_label: ui.first_label,
      last_label: ui.last_label,
      page_info_format: ui.page_info_format
    }
  end

  defp build_empty_state(dsl_state) do
    case find_entity(dsl_state, @table_path, EmptyState) do
      nil ->
        %{message: "No records found", icon: nil, action: nil}

      entity ->
        action =
          if entity.action_label,
            do: %{label: entity.action_label, path: entity.action_path, icon: entity.action_icon},
            else: nil

        %{message: entity.message || "No records found", icon: entity.icon, action: action}
    end
  end

  defp build_error_state(dsl_state) do
    case find_entity(dsl_state, @table_path, ErrorState) do
      nil ->
        %{message: "Error loading data", icon: nil, retry_label: "Retry"}

      entity ->
        %{
          message: entity.message || "Error loading data",
          icon: entity.icon,
          retry_label: entity.retry_label || "Retry"
        }
    end
  end

  defp build_presentation(dsl_state, module, domain_config) do
    path = @table_path ++ [:presentation]
    domain_table = if domain_config, do: domain_config.table, else: %{}

    ui_adapter_raw =
      get_opt(dsl_state, path, :ui_adapter) ||
        domain_table[:ui_adapter] ||
        MishkaGervaz.UIAdapters.Tailwind

    ui_adapter_opts =
      get_opt(dsl_state, path, :ui_adapter_opts) || domain_table[:ui_adapter_opts] || []

    ui_adapter = maybe_generate_adapter(module, ui_adapter_raw, ui_adapter_opts)

    %{
      filter_mode: get_opt(dsl_state, path, :filter_mode) || :inline,
      template: get_opt(dsl_state, path, :template, MishkaGervaz.Table.Templates.Table),
      switchable_templates: get_opt(dsl_state, path, :switchable_templates, []),
      template_options: get_opt(dsl_state, path, :template_options, []),
      features: get_opt(dsl_state, path, :features),
      ui_adapter: ui_adapter,
      ui_adapter_opts: ui_adapter_opts,
      theme: build_theme(dsl_state, domain_table[:theme]),
      responsive: build_responsive(dsl_state, domain_table)
    }
  end

  defp build_theme(dsl_state, domain_theme) do
    path = @table_path ++ [:presentation, :theme]
    keys = [:header_class, :row_class, :border_class, :extra]
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    cond do
      any_set?(Map.values(values)) ->
        %{
          header_class: values.header_class || (domain_theme && domain_theme[:header_class]),
          row_class: values.row_class || (domain_theme && domain_theme[:row_class]),
          border_class: values.border_class || (domain_theme && domain_theme[:border_class]),
          extra: values.extra || (domain_theme && domain_theme[:extra]) || %{}
        }

      domain_theme != nil ->
        %{
          header_class: domain_theme[:header_class],
          row_class: domain_theme[:row_class],
          border_class: domain_theme[:border_class],
          extra: domain_theme[:extra] || %{}
        }

      true ->
        nil
    end
  end

  defp build_responsive(dsl_state, domain_table) do
    path = @table_path ++ [:presentation, :responsive]
    keys = [:hide_on_mobile, :hide_on_tablet, :mobile_layout]
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})
    domain_responsive = domain_table[:responsive]

    cond do
      any_set?(Map.values(values)) ->
        %{
          hide_on_mobile: values.hide_on_mobile || [],
          hide_on_tablet: values.hide_on_tablet || [],
          mobile_layout: values.mobile_layout
        }

      domain_responsive != nil ->
        %{
          hide_on_mobile: domain_responsive[:hide_on_mobile] || [],
          hide_on_tablet: domain_responsive[:hide_on_tablet] || [],
          mobile_layout: domain_responsive[:mobile_layout]
        }

      true ->
        nil
    end
  end

  defp build_hooks(dsl_state) do
    path = @table_path ++ [:hooks]

    keys = [
      :on_load,
      :before_delete,
      :after_delete,
      :on_realtime,
      :on_expand,
      :on_filter,
      :on_event,
      :on_select,
      :on_sort
    ]

    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    if any_set?(Map.values(values)), do: values, else: nil
  end

  defp build_refresh(dsl_state, domain_defaults) do
    path = @table_path ++ [:refresh]
    defaults = domain_defaults[:refresh] || %{}
    keys = [:enabled, :interval, :pause_on_interaction, :show_indicator, :pause_on_blur]
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    if any_set?(Map.values(values)) or map_size(defaults) > 0 do
      %{
        enabled: default_if_nil(values.enabled, default_if_nil(defaults[:enabled], false)),
        interval: default_if_nil(values.interval, defaults[:interval]),
        pause_on_interaction:
          default_if_nil(values.pause_on_interaction, defaults[:pause_on_interaction]),
        show_indicator: default_if_nil(values.show_indicator, defaults[:show_indicator]),
        pause_on_blur: default_if_nil(values.pause_on_blur, defaults[:pause_on_blur])
      }
    else
      nil
    end
  end

  @default_max_filter_length 500

  defp build_url_sync(dsl_state, domain_defaults) do
    path = @table_path ++ [:url_sync]
    defaults = domain_defaults[:url_sync] || %{}
    keys = [:enabled, :mode, :params, :prefix, :max_filter_length, :preserve_params]
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    if any_set?(Map.values(values)) or map_size(defaults) > 0 do
      %{
        enabled: default_if_nil(values.enabled, default_if_nil(defaults[:enabled], false)),
        mode: default_if_nil(values.mode, default_if_nil(defaults[:mode], :read_only)),
        params:
          default_if_nil(
            values.params,
            default_if_nil(defaults[:params], [:filters, :sort, :page])
          ),
        prefix: default_if_nil(values.prefix, defaults[:prefix]),
        max_filter_length:
          default_if_nil(
            values.max_filter_length,
            default_if_nil(defaults[:max_filter_length], @default_max_filter_length)
          ),
        preserve_params: default_if_nil(values.preserve_params, defaults[:preserve_params])
      }
    else
      nil
    end
  end

  defp build_data_loader(dsl_state) do
    case find_entity(dsl_state, @table_path, DataLoader) do
      nil ->
        nil

      entity ->
        %{
          module: entity.module,
          query: entity.query,
          filter_parser: entity.filter_parser,
          pagination: entity.pagination,
          tenant: entity.tenant,
          hooks: entity.hooks,
          relation: entity.relation
        }
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
        |> case do
          config when config == %{} -> nil
          config -> config
        end
    end
  end

  defp build_events(dsl_state) do
    case find_entity(dsl_state, @table_path, Events) do
      nil ->
        nil

      entity ->
        %{
          module: entity.module,
          sanitization: entity.sanitization,
          record: entity.record,
          selection: entity.selection,
          bulk_action: entity.bulk_action,
          hooks: entity.hooks,
          relation_filter: entity.relation_filter
        }
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
        |> case do
          config when config == %{} -> nil
          config -> config
        end
    end
  end

  defp maybe_ui(nil, _, _), do: nil

  defp maybe_ui(ui, to_map_fn, has_values_fn) do
    if has_values_fn.(ui), do: to_map_fn.(ui), else: nil
  end

  defp maybe_generate_adapter(module, adapter, opts) do
    cond do
      adapter == MishkaGervaz.UIAdapters.Dynamic ->
        generate_dynamic_adapter(module, opts)

      Keyword.has_key?(opts, :component_module) ->
        generate_component_adapter(module, opts)

      true ->
        adapter
    end
  end

  defp generate_dynamic_adapter(module, opts) do
    adapter_name = Module.concat(module, :GervazUIAdapter)

    if !Code.ensure_loaded?(adapter_name) do
      contents =
        quote do
          use MishkaGervaz.UIAdapters.Dynamic,
            site: unquote(Keyword.get(opts, :site, "Global")),
            fallback: unquote(Keyword.get(opts, :fallback, MishkaGervaz.UIAdapters.Tailwind)),
            component_renderer: unquote(Keyword.get(opts, :component_renderer)),
            module_resolver: unquote(Keyword.get(opts, :module_resolver))
        end

      Module.create(adapter_name, contents, Macro.Env.location(__ENV__))
    end

    adapter_name
  end

  defp generate_component_adapter(module, opts) do
    adapter_name = Module.concat(module, :GervazUIAdapter)

    if !Code.ensure_loaded?(adapter_name) do
      contents =
        quote do
          use MishkaGervaz.Behaviours.UIAdapter,
            fallback: unquote(Keyword.get(opts, :fallback, MishkaGervaz.UIAdapters.Tailwind)),
            components: unquote(Keyword.get(opts, :component_module)),
            nested_components: unquote(Keyword.get(opts, :nested_components, false)),
            module_prefix: unquote(Keyword.get(opts, :module_prefix)),
            component_prefix: unquote(Keyword.get(opts, :component_prefix))
        end

      Module.create(adapter_name, contents, Macro.Env.location(__ENV__))
    end

    adapter_name
  end
end

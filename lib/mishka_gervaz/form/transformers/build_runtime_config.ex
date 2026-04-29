defmodule MishkaGervaz.Form.Transformers.BuildRuntimeConfig do
  @moduledoc """
  Builds the final runtime configuration from the form DSL state.

  This transformer runs last and compiles the form DSL configuration into
  a map structure that can be efficiently accessed at runtime.

  The compiled configuration is persisted as `:mishka_gervaz_form_config`
  and can be retrieved via `MishkaGervaz.Resource.Info.Form.config/1`.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  import MishkaGervaz.Table.Transformers.Helpers

  alias MishkaGervaz.Form.Entities.{Field, Group, Step, Upload, Submit, Events, Access}

  @form_path [:mishka_gervaz, :form]

  @impl true
  def after?(MishkaGervaz.Form.Transformers.ResolveFields), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)
    domain_defaults = get_domain_defaults(module)
    multitenancy = build_multitenancy(module)

    config = %{
      identity: build_identity(dsl_state),
      source: build_source(dsl_state, domain_defaults, multitenancy),
      multitenancy: multitenancy,
      fields: build_fields(dsl_state, module),
      groups: build_groups(dsl_state),
      layout: build_layout(dsl_state, domain_defaults),
      uploads: build_uploads(dsl_state),
      submit: build_submit(dsl_state, domain_defaults),
      presentation: build_presentation(dsl_state, domain_defaults),
      hooks: build_hooks(dsl_state),
      events: build_events(dsl_state),
      detected_preloads:
        Transformer.get_persisted(dsl_state, :mishka_gervaz_form_detected_preloads, []),
      field_order: Transformer.get_persisted(dsl_state, :mishka_gervaz_form_field_order, [])
    }

    {:ok, Transformer.persist(dsl_state, :mishka_gervaz_form_config, config)}
  end

  defp get_domain_defaults(module) do
    case get_domain_config(module) do
      %{form: form} -> form
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
  rescue
    _ -> %{enabled: false, strategy: nil, attribute: nil, global?: true}
  end

  defp build_identity(dsl_state) do
    path = @form_path ++ [:identity]

    %{
      name: get_opt(dsl_state, path, :name),
      route: get_opt(dsl_state, path, :route),
      stream_name: get_opt(dsl_state, path, :stream_name)
    }
  end

  defp build_source(dsl_state, domain_defaults, _multitenancy) do
    source_path = @form_path ++ [:source]
    actions_path = source_path ++ [:actions]
    preload_path = source_path ++ [:preload]

    domain_actions = domain_defaults[:actions] || %{}

    create = get_opt(dsl_state, actions_path, :create) || domain_actions[:create]
    update = get_opt(dsl_state, actions_path, :update) || domain_actions[:update]
    read = get_opt(dsl_state, actions_path, :read) || domain_actions[:read]

    %{
      actor_key:
        get_opt(dsl_state, source_path, :actor_key) || domain_defaults[:actor_key] ||
          :current_user,
      master_check:
        get_opt(dsl_state, source_path, :master_check) || domain_defaults[:master_check],
      actions: %{
        create: create,
        update: update,
        read: read
      },
      preload: %{
        always: get_opt(dsl_state, preload_path, :always, []),
        master: get_opt(dsl_state, preload_path, :master, []),
        tenant: get_opt(dsl_state, preload_path, :tenant, [])
      },
      restricted: get_opt(dsl_state, source_path, :restricted) || false,
      access_rules: build_access_rules(dsl_state, source_path),
      access_gate: build_access_gate(dsl_state, source_path)
    }
  end

  defp build_access_rules(dsl_state, source_path) do
    dsl_state
    |> get_entities(source_path)
    |> filter_by_type(Access)
    |> Enum.filter(&is_atom(&1.mode))
    |> Map.new(fn rule ->
      {rule.mode, %{restricted: rule.restricted, condition: rule.condition}}
    end)
  end

  defp build_access_gate(dsl_state, source_path) do
    dsl_state
    |> get_entities(source_path)
    |> filter_by_type(Access)
    |> Enum.find(&is_function(&1.mode, 2))
    |> case do
      %{mode: gate} when is_function(gate, 2) -> gate
      _ -> nil
    end
  end

  defp build_fields(dsl_state, module) do
    path = @form_path ++ [:fields]
    entities = get_entities(dsl_state, path)
    fields = filter_by_type(entities, Field)
    field_order_opt = get_opt(dsl_state, path, :field_order)

    if fields != [] or field_order_opt != nil do
      ash_attrs = get_ash_attributes(module)

      %{
        list: Enum.map(fields, &field_to_map(&1, ash_attrs, module)),
        order: Transformer.get_persisted(dsl_state, :mishka_gervaz_form_field_order, [])
      }
    else
      nil
    end
  end

  defp get_ash_attributes(module) do
    module
    |> Ash.Resource.Info.attributes()
    |> Map.new(
      &{&1.name, %{type: &1.type, constraints: &1.constraints, allow_nil?: &1.allow_nil?}}
    )
  rescue
    _ -> %{}
  end

  defp field_to_map(field, ash_attrs, module) do
    attr = Map.get(ash_attrs, field.name, %{})
    id_type = resolve_relation_id_type(field, module)

    %{
      name: field.name,
      type: field.type,
      source: field.source,
      required: default_if_nil(field.required, attr[:allow_nil?] == false),
      visible: field.visible,
      show_on: field.show_on,
      restricted: field.restricted,
      default: field.default,
      depends_on: field.depends_on,
      virtual: field.virtual,
      resource: field.resource,
      derive_value: field.derive_value,
      options: field.options,
      options_source: field.options_source,
      display_field: field.display_field,
      search_field: field.search_field,
      value_field: field.value_field,
      readonly: field.readonly,
      mode: field.mode,
      page_size: field.page_size,
      load_action: field.load_action || :read,
      load: field.load,
      apply: field.apply,
      format: field.format,
      render: field.render,
      position: field.position,
      include_nil: field.include_nil,
      min: field.min,
      max: field.max,
      min_chars: field.min_chars,
      nested_fields: field.nested_fields,
      array_fields: field.array_fields,
      add_label: field.add_label,
      remove_label: field.remove_label,
      type_module: field.type_module,
      id_type: id_type,
      ui: maybe_ui(field.ui, &field_ui_to_map/1, &has_field_ui_values?/1),
      preload: maybe_preload(field.preload)
    }
  end

  defp resolve_relation_id_type(%{type: :relation} = field, module) do
    related_resource = resolve_related_resource(field, module)

    if related_resource do
      get_primary_key_type(related_resource)
    else
      :uuid
    end
  end

  defp resolve_relation_id_type(_, _), do: nil

  defp resolve_related_resource(%{resource: resource}, _) when not is_nil(resource), do: resource

  defp resolve_related_resource(%{name: name, source: source}, module)
       when not is_nil(module) do
    field_name = source || name

    module
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

  defp has_field_ui_values?(%Field.Ui{} = ui) do
    any_set?([
      ui.label,
      ui.placeholder,
      ui.description,
      ui.icon,
      ui.class,
      ui.wrapper_class,
      ui.debounce,
      ui.span,
      ui.rows,
      ui.step,
      ui.autocomplete,
      ui.add_label,
      ui.remove_label,
      ui.disabled_prompt
    ]) or ui.extra != %{}
  end

  defp has_field_ui_values?(_), do: false

  defp field_ui_to_map(%Field.Ui{} = ui) do
    %{
      label: ui.label,
      placeholder: ui.placeholder,
      description: ui.description,
      icon: ui.icon,
      class: ui.class,
      wrapper_class: ui.wrapper_class,
      debounce: ui.debounce,
      span: ui.span,
      rows: ui.rows,
      step: ui.step,
      autocomplete: ui.autocomplete,
      add_label: ui.add_label,
      remove_label: ui.remove_label,
      disabled_prompt: ui.disabled_prompt,
      extra: ui.extra
    }
  end

  defp maybe_preload(nil), do: nil

  defp maybe_preload(%Field.Preload{} = preload) do
    if preload.always == [] and preload.master == [] and preload.tenant == [] do
      nil
    else
      %{always: preload.always, master: preload.master, tenant: preload.tenant}
    end
  end

  defp maybe_preload([preload | _]) when is_struct(preload, Field.Preload),
    do: maybe_preload(preload)

  defp maybe_preload(_), do: nil

  defp build_groups(dsl_state) do
    path = @form_path ++ [:groups]
    groups = get_entities(dsl_state, path) |> filter_by_type(Group)
    if groups != [], do: Enum.map(groups, &group_to_map/1), else: nil
  end

  defp group_to_map(group) do
    %{
      name: group.name,
      fields: group.fields,
      collapsed: group.collapsed,
      collapsible: group.collapsible,
      visible: group.visible,
      restricted: group.restricted,
      position: group.position,
      ui: maybe_ui(group.ui, &group_ui_to_map/1, &has_group_ui_values?/1)
    }
  end

  defp has_group_ui_values?(%Group.Ui{} = ui) do
    any_set?([ui.label, ui.icon, ui.description, ui.class, ui.header_class, ui.columns]) or
      ui.extra != %{}
  end

  defp has_group_ui_values?(_), do: false

  defp group_ui_to_map(%Group.Ui{} = ui) do
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

  defp build_layout(dsl_state, domain_defaults) do
    path = @form_path ++ [:layout]
    domain_layout = domain_defaults[:layout]

    values =
      [:columns, :mode, :navigation, :persistence, :responsive]
      |> Map.new(&{&1, get_opt(dsl_state, path, &1)})

    steps = get_entities(dsl_state, path) |> filter_by_type(Step)

    has_values = any_set?(Map.values(values)) or steps != [] or is_map(domain_layout)

    if has_values do
      %{
        columns: values.columns || (domain_layout && domain_layout[:columns]) || 1,
        mode: default_if_nil(values.mode, :standard),
        navigation:
          values.navigation || (domain_layout && domain_layout[:navigation]) || :sequential,
        persistence:
          values.persistence || (domain_layout && domain_layout[:persistence]) || :none,
        responsive:
          if(values.responsive != nil,
            do: values.responsive,
            else: (domain_layout && domain_layout[:responsive]) || true
          ),
        steps: if(steps != [], do: Enum.map(steps, &step_to_map/1), else: nil)
      }
    else
      nil
    end
  end

  defp step_to_map(step) do
    %{
      name: step.name,
      groups: step.groups,
      action: step.action,
      visible: step.visible,
      summary: step.summary,
      on_enter: step.on_enter,
      before_leave: step.before_leave,
      after_leave: step.after_leave,
      ui: maybe_ui(step.ui, &step_ui_to_map/1, &has_step_ui_values?/1)
    }
  end

  defp has_step_ui_values?(%Step.Ui{} = ui) do
    any_set?([ui.label, ui.icon, ui.description, ui.class, ui.header_class]) or ui.extra != %{}
  end

  defp has_step_ui_values?(_), do: false

  defp step_ui_to_map(%Step.Ui{} = ui) do
    %{
      label: ui.label,
      icon: ui.icon,
      description: ui.description,
      class: ui.class,
      header_class: ui.header_class,
      extra: ui.extra
    }
  end

  defp build_uploads(dsl_state) do
    path = @form_path ++ [:uploads]
    uploads = get_entities(dsl_state, path) |> filter_by_type(Upload)

    if uploads != [], do: Enum.map(uploads, &upload_to_map/1), else: nil
  end

  defp upload_to_map(upload) do
    %{
      name: upload.name,
      field: upload.field,
      accept: upload.accept,
      max_entries: upload.max_entries,
      max_file_size: upload.max_file_size,
      show_preview: upload.show_preview,
      dropzone_text: upload.dropzone_text,
      auto_upload: upload.auto_upload,
      style: upload.style || :dropzone,
      chunk_size: upload.chunk_size,
      chunk_timeout: upload.chunk_timeout,
      external: upload.external,
      writer: upload.writer,
      existing: upload.existing,
      ui: maybe_ui(upload.ui, &upload_ui_to_map/1, &has_upload_ui_values?/1)
    }
  end

  defp has_upload_ui_values?(%Upload.Ui{} = ui) do
    any_set?([ui.label, ui.icon, ui.class, ui.preview_class]) or ui.extra != %{}
  end

  defp has_upload_ui_values?(_), do: false

  defp upload_ui_to_map(%Upload.Ui{} = ui) do
    %{
      label: ui.label,
      icon: ui.icon,
      class: ui.class,
      preview_class: ui.preview_class,
      extra: ui.extra
    }
  end

  defp build_submit(dsl_state, _domain_defaults) do
    case find_entity(dsl_state, @form_path, Submit) do
      nil -> nil
      %Submit{} = entity -> entity_to_raw_map(entity)
    end
  end

  defp entity_to_raw_map(%Submit{} = entity) do
    %{
      create: button_to_raw_map(entity.create),
      update: button_to_raw_map(entity.update),
      cancel: button_to_raw_map(entity.cancel),
      position: entity.position,
      ui: ui_to_raw_map(entity.ui)
    }
  end

  defp button_to_raw_map(nil), do: nil

  defp button_to_raw_map(%Submit.Button{} = btn) do
    %{
      label: btn.label,
      active: btn.active,
      disabled: btn.disabled,
      restricted: btn.restricted,
      visible: btn.visible
    }
  end

  defp ui_to_raw_map(nil), do: nil

  defp ui_to_raw_map(%Submit.Ui{} = ui) do
    if any_set?([ui.submit_class, ui.cancel_class, ui.wrapper_class]) or ui.extra != %{} do
      %{
        submit_class: ui.submit_class,
        cancel_class: ui.cancel_class,
        wrapper_class: ui.wrapper_class,
        extra: ui.extra
      }
    else
      nil
    end
  end

  defp build_presentation(dsl_state, domain_defaults) do
    path = @form_path ++ [:presentation]
    theme_path = path ++ [:theme]

    %{
      debounce: get_opt(dsl_state, path, :debounce) || domain_defaults[:debounce],
      template:
        get_opt(dsl_state, path, :template) || domain_defaults[:template] ||
          MishkaGervaz.Form.Templates.Standard,
      features: get_opt(dsl_state, path, :features) || domain_defaults[:features],
      ui_adapter:
        get_opt(dsl_state, path, :ui_adapter) || domain_defaults[:ui_adapter] ||
          MishkaGervaz.UIAdapters.Tailwind,
      ui_adapter_opts: get_opt(dsl_state, path, :ui_adapter_opts) || [],
      theme: build_theme(dsl_state, theme_path, domain_defaults)
    }
  end

  defp build_theme(dsl_state, path, domain_defaults) do
    domain_theme = domain_defaults[:theme]
    keys = [:form_class, :field_class, :label_class, :error_class, :extra]
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    cond do
      any_set?(Map.values(values)) ->
        %{
          form_class: values.form_class || (domain_theme && domain_theme[:form_class]),
          field_class: values.field_class || (domain_theme && domain_theme[:field_class]),
          label_class: values.label_class || (domain_theme && domain_theme[:label_class]),
          error_class: values.error_class || (domain_theme && domain_theme[:error_class]),
          extra: values.extra || (domain_theme && domain_theme[:extra]) || %{}
        }

      domain_theme != nil ->
        %{
          form_class: domain_theme[:form_class],
          field_class: domain_theme[:field_class],
          label_class: domain_theme[:label_class],
          error_class: domain_theme[:error_class],
          extra: domain_theme[:extra] || %{}
        }

      true ->
        nil
    end
  end

  defp build_hooks(dsl_state) do
    path = @form_path ++ [:hooks]

    keys = [
      :on_init,
      :before_save,
      :after_save,
      :on_error,
      :on_cancel,
      :on_validate,
      :on_change,
      :transform_params,
      :transform_errors
    ]

    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})
    js = build_js_hooks(dsl_state)
    values = if js, do: Map.put(values, :js, js), else: values

    if any_set?(Map.values(values)), do: values, else: nil
  end

  defp build_js_hooks(dsl_state) do
    path = @form_path ++ [:hooks, :js]
    keys = [:on_init, :after_save, :on_cancel, :on_error]
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})
    if any_set?(Map.values(values)), do: values, else: nil
  end

  defp build_events(dsl_state) do
    case find_entity(dsl_state, @form_path, Events) do
      nil ->
        nil

      entity ->
        %{
          module: entity.module,
          sanitization: entity.sanitization,
          validation: entity.validation,
          submit: entity.submit,
          step: entity.step,
          upload: entity.upload,
          relation: entity.relation,
          hooks: entity.hooks
        }
    end
  end

  defp maybe_ui(nil, _, _), do: nil

  defp maybe_ui(ui, to_map_fn, has_values_fn) do
    if has_values_fn.(ui), do: to_map_fn.(ui), else: nil
  end
end

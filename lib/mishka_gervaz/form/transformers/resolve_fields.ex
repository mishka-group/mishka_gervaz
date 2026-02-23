defmodule MishkaGervaz.Form.Transformers.ResolveFields do
  @moduledoc """
  Resolves field configurations from the DSL.

  This transformer:

  - Processes `auto_fields` to discover fields from Ash resource attributes
  - Auto-detects field types from Ash types
  - Resolves field positions
  - Applies field order
  - Detects required preloads from relationship sources
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  alias MishkaGervaz.Form.Entities.Field
  alias MishkaGervaz.Form.Entities.NestedField
  alias MishkaGervaz.Form.Entities.AutoFields
  import MishkaGervaz.Table.Transformers.Helpers

  @fields_path [:mishka_gervaz, :form, :fields]

  @impl true
  @spec after?(module()) :: boolean()
  def after?(MishkaGervaz.Form.Transformers.MergeDefaults), do: true
  def after?(Ash.Resource.Transformers.SetTypes), do: true
  def after?(_), do: false

  @impl true
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)

    dsl_state =
      dsl_state
      |> resolve_auto_fields(module)
      |> resolve_explicit_field_types()
      |> resolve_field_sources()
      |> resolve_relation_resources(module)
      |> resolve_field_positions()
      |> detect_preloads()

    {:ok, dsl_state}
  end

  @spec filter_fields([struct()]) :: [Field.t()]
  defp filter_fields(entities),
    do: Enum.filter(entities, &match?(%Field{}, &1))

  @spec resolve_auto_fields(Spark.Dsl.t(), module()) :: Spark.Dsl.t()
  defp resolve_auto_fields(dsl_state, _module) do
    entities = get_entities(dsl_state, @fields_path)

    case Enum.find(entities, &match?(%AutoFields{}, &1)) do
      nil -> dsl_state
      config -> process_auto_fields(dsl_state, entities, config)
    end
  end

  @spec process_auto_fields(Spark.Dsl.t(), [struct()], AutoFields.t()) :: Spark.Dsl.t()
  defp process_auto_fields(dsl_state, entities, config) do
    explicit = filter_fields(entities)

    new_fields =
      explicit
      |> Enum.map(& &1.name)
      |> then(&discover_fields(dsl_state, config, &1))
      |> build_auto_fields(dsl_state, config)

    dsl_state
    |> remove_all_field_entities(entities)
    |> add_field_entities(combine_fields(config.position, new_fields, explicit))
  end

  @spec combine_fields(:start | :end, [Field.t()], [Field.t()]) :: [Field.t()]
  defp combine_fields(:start, new, explicit), do: new ++ explicit
  defp combine_fields(:end, new, explicit), do: explicit ++ new

  @spec discover_fields(Spark.Dsl.t(), AutoFields.t(), [atom()]) :: [atom()]
  defp discover_fields(dsl_state, config, explicit_fields) do
    names = get_attribute_names(dsl_state)

    if config.only do
      Enum.filter(names, &(&1 in config.only))
    else
      Enum.reject(names, &(&1 in config.except))
    end
    |> Enum.reject(&(&1 in explicit_fields))
  end

  @spec get_attribute_names(Spark.Dsl.t()) :: [atom()]
  defp get_attribute_names(dsl_state) do
    dsl_state |> Transformer.get_entities([:attributes]) |> Enum.map(& &1.name)
  rescue
    _ -> []
  end

  @spec build_auto_fields([atom()], Spark.Dsl.t(), AutoFields.t()) :: [Field.t()]
  defp build_auto_fields(discovered, dsl_state, config) do
    defaults = extract_defaults(config.defaults)
    ui_defaults = extract_ui_defaults(config.ui_defaults)
    ash_attrs = get_ash_attributes(dsl_state)

    Enum.map(discovered, fn attr_name ->
      override = Enum.find(config.overrides || [], &(&1.name == attr_name))
      ash_attr = Map.get(ash_attrs, attr_name)
      detected_type = infer_field_type(ash_attr, ui_defaults)

      final_type = (override && override.type) || detected_type
      override_options = if override, do: Map.get(override, :options), else: nil
      options = maybe_infer_options(final_type, override_options, ash_attr)
      nested_fields = maybe_infer_nested_fields(final_type, [], ash_attr, false)

      ui =
        if final_type == :nested and nested_fields != [] do
          nested_mode = detect_nested_mode(ash_attr)
          nested_source = detect_nested_source(ash_attr)
          base_ui = normalize_ui(override && override.ui)

          extra =
            (base_ui.extra || %{})
            |> Map.put(:nested_mode, nested_mode)
            |> Map.put(:nested_source, nested_source)

          %{base_ui | extra: extra}
        else
          override && override.ui
        end

      %Field{
        name: attr_name,
        source: attr_name,
        type: final_type,
        options: options,
        nested_fields: nested_fields,
        required: default_if_nil(override && override.required, defaults.required),
        visible: default_if_nil(override && override.visible, defaults.visible),
        readonly: default_if_nil(override && override.readonly, defaults.readonly),
        format: override && override.format,
        ui: ui
      }
    end)
  end

  @spec extract_defaults(list() | struct() | nil) :: AutoFields.Defaults.t()
  defp extract_defaults([d | _]), do: d
  defp extract_defaults(d) when is_struct(d), do: d
  defp extract_defaults(_), do: %AutoFields.Defaults{}

  @spec extract_ui_defaults(list() | struct() | nil) :: AutoFields.UiDefaults.t()
  defp extract_ui_defaults([d | _]), do: d
  defp extract_ui_defaults(d) when is_struct(d), do: d
  defp extract_ui_defaults(_), do: %AutoFields.UiDefaults{}

  @spec get_ash_attributes(Spark.Dsl.t()) :: map()
  defp get_ash_attributes(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:attributes])
    |> Map.new(&{&1.name, %{type: &1.type, constraints: &1.constraints}})
  rescue
    _ -> %{}
  end

  @spec infer_field_type(map() | nil, AutoFields.UiDefaults.t()) :: atom()
  defp infer_field_type(nil, _ui_defaults), do: :text

  defp infer_field_type(%{type: type, constraints: constraints}, ui_defaults) do
    cond do
      type == Ash.Type.Boolean ->
        ui_defaults.boolean_widget

      type == Ash.Type.Integer or type == Ash.Type.Float or type == Ash.Type.Decimal ->
        :number

      type == Ash.Type.Date ->
        :date

      type in [Ash.Type.DateTime, Ash.Type.UtcDatetime, Ash.Type.UtcDatetimeUsec] ->
        :datetime

      type == Ash.Type.Map ->
        if has_constrained_fields?(constraints), do: :nested, else: :json

      type == Ash.Type.UUID or type == Ash.Type.UUIDv7 ->
        :hidden

      type == Ash.Type.Atom ->
        infer_atom_type(constraints)

      type == Ash.Type.String ->
        infer_string_type(constraints, ui_defaults)

      is_array_of_constrained_maps?(type, constraints) ->
        :nested

      match?({:array, _}, type) ->
        infer_array_type(type)

      is_atom(type) and type != nil and Ash.Type.embedded_type?(type) ->
        :nested

      true ->
        :text
    end
  end

  @spec infer_atom_type(keyword() | nil) :: atom()
  defp infer_atom_type(nil), do: :text

  defp infer_atom_type(constraints) when is_list(constraints) do
    if Keyword.has_key?(constraints, :one_of), do: :select, else: :text
  end

  defp infer_atom_type(_), do: :text

  @spec infer_string_type(keyword() | nil, AutoFields.UiDefaults.t()) :: atom()
  defp infer_string_type(nil, _), do: :text

  defp infer_string_type(constraints, ui_defaults) when is_list(constraints) do
    cond do
      Keyword.has_key?(constraints, :one_of) -> :select
      (Keyword.get(constraints, :max_length) || 0) > ui_defaults.textarea_threshold -> :textarea
      true -> :text
    end
  end

  defp infer_string_type(_, _), do: :text

  @spec infer_array_type({:array, any()}) :: atom()
  defp infer_array_type({:array, Ash.Type.String}), do: :string_list
  defp infer_array_type({:array, :string}), do: :string_list

  defp infer_array_type({:array, type}) when is_atom(type) do
    if Ash.Type.embedded_type?(type), do: :nested, else: :json
  end

  defp infer_array_type(_), do: :json

  defp is_array_of_constrained_maps?({:array, type}, constraints)
       when type in [Ash.Type.Map, :map] do
    has_constrained_fields?(constraints)
  end

  defp is_array_of_constrained_maps?(_, _), do: false

  defp has_constrained_fields?(constraints) when is_list(constraints) do
    case Keyword.get(constraints, :items) do
      items when is_list(items) -> Keyword.has_key?(items, :fields)
      _ -> false
    end
  end

  defp has_constrained_fields?(_), do: false

  @spec remove_all_field_entities(Spark.Dsl.t(), [struct()]) :: Spark.Dsl.t()
  defp remove_all_field_entities(dsl_state, entities) do
    Enum.reduce(entities, dsl_state, fn entity, acc ->
      cond do
        match?(%Field{}, entity) ->
          Transformer.remove_entity(acc, @fields_path, &(&1 == entity))

        match?(%AutoFields{}, entity) ->
          Transformer.remove_entity(acc, @fields_path, &match?(%AutoFields{}, &1))

        true ->
          acc
      end
    end)
  end

  @spec add_field_entities(Spark.Dsl.t(), [Field.t()]) :: Spark.Dsl.t()
  defp add_field_entities(dsl_state, fields) do
    Enum.reduce(fields, dsl_state, fn field, acc ->
      Transformer.add_entity(acc, @fields_path, field, type: :append)
    end)
  end

  @spec resolve_explicit_field_types(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_explicit_field_types(dsl_state) do
    fields = filter_fields(get_entities(dsl_state, @fields_path))
    ash_attrs = get_ash_attributes(dsl_state)
    ui_defaults = %AutoFields.UiDefaults{}

    {updated, changed?} =
      Enum.map_reduce(fields, false, fn field, changed? ->
        ash_attr = Map.get(ash_attrs, field.source || field.name)

        cond do
          is_nil(field.type) ->
            detected = infer_field_type(ash_attr, ui_defaults)
            type_module = MishkaGervaz.Form.Types.Field.get_or_passthrough(detected)
            options = maybe_infer_options(detected, field.options, ash_attr)

            nested_fields =
              maybe_infer_nested_fields(
                detected,
                field.nested_fields,
                ash_attr,
                field.auto_fields
              )

            ui =
              if detected == :nested and nested_fields != [] do
                nested_mode = detect_nested_mode(ash_attr)
                nested_source = detect_nested_source(ash_attr)
                base_ui = normalize_ui(field.ui)

                extra =
                  (base_ui.extra || %{})
                  |> Map.put(:nested_mode, nested_mode)
                  |> Map.put(:nested_source, nested_source)

                %{base_ui | extra: extra}
              else
                field.ui
              end

            {%{
               field
               | type: detected,
                 type_module: type_module,
                 options: options,
                 nested_fields: nested_fields,
                 ui: ui
             }, true}

          field.type == :nested ->
            nested_fields =
              maybe_infer_nested_fields(
                :nested,
                field.nested_fields,
                ash_attr,
                field.auto_fields
              )

            if nested_fields != [] do
              nested_mode = detect_nested_mode(ash_attr)
              nested_source = detect_nested_source(ash_attr)
              ui = normalize_ui(field.ui)

              extra =
                (ui.extra || %{})
                |> Map.put(:nested_mode, nested_mode)
                |> Map.put(:nested_source, nested_source)

              ui = %{ui | extra: extra}
              {%{field | nested_fields: nested_fields, ui: ui}, true}
            else
              {field, changed?}
            end

          field.type == :select and is_nil(field.options) ->
            options = extract_one_of_options(ash_attr)
            if options, do: {%{field | options: options}, true}, else: {field, changed?}

          true ->
            {field, changed?}
        end
      end)

    if changed? do
      dsl_state
      |> remove_field_entities(fields)
      |> add_field_entities(updated)
    else
      dsl_state
    end
  end

  @spec maybe_infer_options(atom(), list() | nil, map() | nil) :: list() | nil
  defp maybe_infer_options(:select, nil, ash_attr), do: extract_one_of_options(ash_attr)
  defp maybe_infer_options(_type, existing, _ash_attr), do: existing

  @spec maybe_infer_nested_fields(atom(), list(), map() | nil, boolean()) :: list()
  defp maybe_infer_nested_fields(:nested, existing, ash_attr, auto_fields) do
    explicit = Enum.filter(existing, &is_struct(&1, NestedField))
    maps = Enum.filter(existing, &(is_map(&1) and not is_struct(&1)))
    inferred = infer_from_embedded_type(ash_attr)

    cond do
      explicit != [] -> merge_nested_fields(explicit, inferred, auto_fields)
      maps != [] -> maps
      true -> inferred
    end
  end

  defp maybe_infer_nested_fields(_, existing, _, _), do: existing

  defp infer_from_embedded_type(%{type: {:array, type}, constraints: constraints})
       when type in [Ash.Type.Map, :map] do
    infer_nested_fields_from_constrained_map(constraints)
  end

  defp infer_from_embedded_type(%{type: Ash.Type.Map, constraints: constraints}) do
    infer_nested_fields_from_constrained_map(constraints)
  end

  defp infer_from_embedded_type(%{type: {:array, type}}) when is_atom(type) do
    infer_nested_fields_from_embedded(type)
  end

  defp infer_from_embedded_type(%{type: type}) when is_atom(type) do
    if Ash.Type.embedded_type?(type), do: infer_nested_fields_from_embedded(type), else: []
  rescue
    _ -> []
  end

  defp infer_from_embedded_type(_), do: []

  defp infer_nested_fields_from_embedded(type) do
    ui_defaults = %AutoFields.UiDefaults{}

    type
    |> Ash.Resource.Info.attributes()
    |> Enum.filter(& &1.public?)
    |> Enum.reject(&(&1.name in [:id, :inserted_at, :updated_at]))
    |> Enum.map(fn attr ->
      sub_type = infer_field_type(%{type: attr.type, constraints: attr.constraints}, ui_defaults)
      label = attr.name |> to_string() |> String.replace("_", " ") |> String.capitalize()

      %{
        name: attr.name,
        type: sub_type,
        label: label,
        placeholder: label,
        required: !attr.allow_nil?
      }
    end)
  rescue
    _ -> []
  end

  defp infer_nested_fields_from_constrained_map(constraints) when is_list(constraints) do
    with items when is_list(items) <- Keyword.get(constraints, :items),
         fields when is_list(fields) <- Keyword.get(items, :fields) do
      Enum.map(fields, fn {field_name, field_config} ->
        field_type = Keyword.get(field_config, :type, :string)
        sub_type = constraint_type_to_field_type(field_type)
        label = humanize_name(field_name)

        %{
          name: field_name,
          type: sub_type,
          ash_type: field_type,
          label: label,
          placeholder: label,
          required: !Keyword.get(field_config, :allow_nil?, true)
        }
      end)
    else
      _ -> []
    end
  end

  defp infer_nested_fields_from_constrained_map(_), do: []

  defp constraint_type_to_field_type(:string), do: :text
  defp constraint_type_to_field_type(:integer), do: :number
  defp constraint_type_to_field_type(:float), do: :number
  defp constraint_type_to_field_type(:decimal), do: :number
  defp constraint_type_to_field_type(:boolean), do: :checkbox
  defp constraint_type_to_field_type(:date), do: :date
  defp constraint_type_to_field_type(:map), do: :json
  defp constraint_type_to_field_type({:array, _}), do: :json
  defp constraint_type_to_field_type(_), do: :text

  defp merge_nested_fields(explicit, inferred, auto_fields) do
    explicit_map = Map.new(explicit, &{&1.name, &1})

    if auto_fields do
      # Replace in-place: walk inferred order, apply overrides where they exist
      merged =
        Enum.map(inferred, fn inf ->
          case Map.get(explicit_map, inf.name) do
            nil -> inf
            nf -> resolve_nested_field(nf, inf)
          end
        end)

      # Add any explicit fields not found in inferred (e.g. virtual nested fields)
      inferred_names = MapSet.new(inferred, & &1.name)

      extra =
        explicit
        |> Enum.reject(fn nf -> MapSet.member?(inferred_names, nf.name) end)
        |> Enum.map(fn nf -> resolve_nested_field(nf, nil) end)

      apply_nested_positions(merged ++ extra)
    else
      Enum.map(explicit, fn nf ->
        base = Enum.find(inferred, &(&1.name == nf.name))
        resolve_nested_field(nf, base)
      end)
    end
  end

  defp apply_nested_positions(fields) do
    has_positions? = Enum.any?(fields, fn f -> Map.get(f, :position) != nil end)

    if has_positions? do
      {firsts, rest} = Enum.split_with(fields, &(Map.get(&1, :position) == :first))
      {lasts, rest} = Enum.split_with(rest, &(Map.get(&1, :position) == :last))
      {positioned, normal} = Enum.split_with(rest, &(Map.get(&1, :position) != nil))

      result =
        positioned
        |> Enum.sort_by(fn f ->
          case Map.get(f, :position) do
            n when is_integer(n) -> {0, n}
            _ -> {1, 0}
          end
        end)
        |> Enum.reduce(normal, fn field, acc ->
          case Map.get(field, :position) do
            n when is_integer(n) ->
              List.insert_at(acc, min(n, length(acc)), field)

            {:before, target} ->
              case Enum.find_index(acc, &(&1.name == target)) do
                nil -> acc ++ [field]
                idx -> List.insert_at(acc, idx, field)
              end

            {:after, target} ->
              case Enum.find_index(acc, &(&1.name == target)) do
                nil -> acc ++ [field]
                idx -> List.insert_at(acc, idx + 1, field)
              end
          end
        end)

      firsts ++ result ++ lasts
    else
      fields
    end
  end

  defp resolve_nested_field(%NestedField{} = nf, base) do
    ui = nf.ui
    base_type = if base, do: base.type, else: :text
    base_label = if base, do: base.label, else: humanize_name(nf.name)
    base_required = if base, do: base.required, else: false
    base_ash_type = if base, do: Map.get(base, :ash_type), else: nil

    %{
      name: nf.name,
      type: nf.type || base_type,
      ash_type: base_ash_type,
      label: (ui && resolve_label_value(ui.label)) || base_label,
      placeholder: (ui && ui.placeholder) || (ui && resolve_label_value(ui.label)) || base_label,
      required: if(is_nil(nf.required), do: base_required, else: nf.required),
      visible: nf.visible,
      readonly: nf.readonly,
      default: nf.default,
      options: nf.options,
      rows: ui && ui.rows,
      class: ui && ui.class,
      span: ui && ui.span,
      description: ui && ui.description,
      position: nf.position
    }
  end

  defp humanize_name(name) do
    name |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp resolve_label_value(nil), do: nil
  defp resolve_label_value(f) when is_function(f, 0), do: f
  defp resolve_label_value(s) when is_binary(s), do: s
  defp resolve_label_value(_), do: nil

  defp detect_nested_mode(%{type: {:array, _}}), do: :array
  defp detect_nested_mode(_), do: :single

  defp detect_nested_source(%{type: {:array, type}}) when type in [Ash.Type.Map, :map],
    do: :constrained_map

  defp detect_nested_source(%{type: type}) when type in [Ash.Type.Map, :map],
    do: :constrained_map

  defp detect_nested_source(_), do: :embedded

  defp normalize_ui(%Field.Ui{} = ui), do: ui
  defp normalize_ui(nil), do: %Field.Ui{}
  defp normalize_ui([]), do: %Field.Ui{}
  defp normalize_ui([ui | _]) when is_struct(ui, Field.Ui), do: ui
  defp normalize_ui(_), do: %Field.Ui{}

  @spec extract_one_of_options(map() | nil) :: list() | nil
  defp extract_one_of_options(nil), do: nil

  defp extract_one_of_options(%{constraints: constraints}) when is_list(constraints) do
    case Keyword.get(constraints, :one_of) do
      nil ->
        nil

      values when is_list(values) ->
        Enum.map(values, fn val ->
          label = val |> to_string() |> String.replace("_", " ") |> String.capitalize()
          {label, val}
        end)
    end
  end

  defp extract_one_of_options(_), do: nil

  @spec resolve_field_sources(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_field_sources(dsl_state) do
    entities = get_entities(dsl_state, @fields_path)

    updated =
      Enum.map(entities, fn
        %Field{source: nil, name: name} = field -> %{field | source: name}
        other -> other
      end)

    dsl_state
    |> remove_field_entities(entities)
    |> add_field_entities(Enum.filter(updated, &match?(%Field{}, &1)))
  end

  @spec remove_field_entities(Spark.Dsl.t(), [struct()]) :: Spark.Dsl.t()
  defp remove_field_entities(dsl_state, entities) do
    Enum.reduce(entities, dsl_state, fn entity, acc ->
      if match?(%Field{}, entity) do
        Transformer.remove_entity(acc, @fields_path, &(&1.name == entity.name))
      else
        acc
      end
    end)
  end

  @spec resolve_relation_resources(Spark.Dsl.t(), module()) :: Spark.Dsl.t()
  defp resolve_relation_resources(dsl_state, _module) do
    entities = get_entities(dsl_state, @fields_path)
    fields = filter_fields(entities)
    relationships = get_relationships(dsl_state)

    {updated, changed?} =
      Enum.map_reduce(fields, false, fn field, changed? ->
        if field.type == :relation and is_nil(field.resource) do
          case resolve_related_resource(field, relationships) do
            nil -> {field, changed?}
            resource -> {%{field | resource: resource}, true}
          end
        else
          {field, changed?}
        end
      end)

    if changed? do
      dsl_state
      |> remove_field_entities(fields)
      |> add_field_entities(updated)
    else
      dsl_state
    end
  end

  defp resolve_related_resource(field, relationships) do
    field_name = field.source || field.name

    relationships
    |> Enum.find(&(&1.source_attribute == field_name))
    |> case do
      %{destination: dest} -> dest
      nil -> nil
    end
  end

  defp get_relationships(dsl_state) do
    Transformer.get_entities(dsl_state, [:relationships])
  rescue
    _ -> []
  end

  @spec resolve_field_positions(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_field_positions(dsl_state) do
    field_order = get_opt(dsl_state, @fields_path, :field_order)

    sorted_names =
      dsl_state
      |> get_entities(@fields_path)
      |> filter_fields()
      |> sort_fields(field_order)
      |> Enum.map(& &1.name)

    Transformer.persist(dsl_state, :mishka_gervaz_form_field_order, sorted_names)
  end

  @spec sort_fields([Field.t()], [atom()] | nil) :: [Field.t()]
  defp sort_fields(fields, nil) do
    fields
    |> Enum.with_index()
    |> Enum.sort_by(fn {field, idx} -> position_sort_key(field.position, idx) end)
    |> Enum.map(&elem(&1, 0))
  end

  defp sort_fields(fields, field_order) do
    {in_order, not_in_order} = Enum.split_with(fields, &(&1.name in field_order))

    ordered =
      field_order
      |> Enum.map(fn name -> Enum.find(in_order, &(&1.name == name)) end)
      |> Enum.reject(&is_nil/1)

    ordered ++ not_in_order
  end

  @spec position_sort_key(atom() | integer() | {atom(), atom()} | nil, non_neg_integer()) ::
          {number(), number()}
  defp position_sort_key(nil, idx), do: {1, idx}
  defp position_sort_key(:first, _), do: {0, 0}
  defp position_sort_key(:last, _), do: {2, 0}
  defp position_sort_key(n, _) when is_integer(n), do: {1, n}
  defp position_sort_key({:before, _}, idx), do: {1, idx - 0.5}
  defp position_sort_key({:after, _}, idx), do: {1, idx + 0.5}

  @spec detect_preloads(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp detect_preloads(dsl_state) do
    preloads =
      dsl_state
      |> get_entities(@fields_path)
      |> filter_fields()
      |> Enum.filter(&(&1.type in [:relation, :select] and not is_nil(&1.resource)))
      |> Enum.map(& &1.source)
      |> Enum.uniq()

    Transformer.persist(dsl_state, :mishka_gervaz_form_detected_preloads, preloads)
  end
end

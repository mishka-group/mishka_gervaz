defmodule MishkaGervaz.Form.Transformers.ResolveFields do
  @moduledoc """
  Resolves field configurations from the form DSL.

  Stages, in order (see `transform/1`):

    * `resolve_auto_fields/1` — expands `auto_fields do … end` into
      explicit `Field` entities, detecting types from the resource's
      Ash attributes.
    * `resolve_explicit_field_types/1` — fills in the `type`,
      `type_module`, `options`, and `nested_fields` for fields that
      omit `type:` or use `:nested`.
    * `resolve_field_sources/1` — defaults `field.source` to the
      field's `name` when not set.
    * `resolve_relation_resources/1` — links `:relation` fields to
      their target resource via the Ash relationship table.
    * `resolve_field_positions/1` — applies `field_order` and the
      `:first` / `:last` / integer / `{:before, …}` / `{:after, …}`
      position tokens, persisting the resolved order under
      `:mishka_gervaz_form_field_order`.
    * `detect_preloads/1` — collects required preloads from
      `:relation` and `:select` fields, persisting them under
      `:mishka_gervaz_form_detected_preloads`.

  Runs after `MishkaGervaz.Form.Transformers.MergeDefaults` and the
  Ash `SetTypes` transformer; output is consumed by
  `MishkaGervaz.Form.Transformers.BuildRuntimeConfig`.
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
    dsl_state =
      dsl_state
      |> resolve_auto_fields()
      |> resolve_explicit_field_types()
      |> resolve_field_sources()
      |> resolve_relation_resources()
      |> resolve_field_positions()
      |> detect_preloads()

    {:ok, dsl_state}
  end

  @spec filter_fields([struct()]) :: [Field.t()]
  defp filter_fields(entities),
    do: Enum.filter(entities, &match?(%Field{}, &1))

  @spec resolve_auto_fields(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_auto_fields(dsl_state) do
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

      final_type = (override && override.type) || infer_field_type(ash_attr, ui_defaults)
      override_options = if override, do: Map.get(override, :options), else: nil
      nested_fields = maybe_infer_nested_fields(final_type, [], ash_attr, false)

      ui =
        if final_type == :nested and nested_fields != [] do
          base_ui = normalize_ui(override && override.ui)

          extra =
            (base_ui.extra || %{})
            |> Map.put(:nested_mode, detect_nested_mode(ash_attr))
            |> Map.put(:nested_source, detect_nested_source(ash_attr))

          %{base_ui | extra: extra}
        else
          override && override.ui
        end

      %Field{
        name: attr_name,
        source: attr_name,
        type: final_type,
        options: maybe_infer_options(final_type, override_options, ash_attr),
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
    ash_attrs = get_ash_attributes(dsl_state)
    ui_defaults = %AutoFields.UiDefaults{}

    dsl_state
    |> get_entities(@fields_path)
    |> filter_fields()
    |> Enum.reduce(dsl_state, fn field, acc ->
      case maybe_resolve_field_type(field, ash_attrs, ui_defaults) do
        ^field -> acc
        updated -> Transformer.replace_entity(acc, @fields_path, updated)
      end
    end)
  end

  @spec maybe_resolve_field_type(Field.t(), map(), AutoFields.UiDefaults.t()) :: Field.t()
  defp maybe_resolve_field_type(%Field{type: nil} = field, ash_attrs, ui_defaults) do
    ash_attr = Map.get(ash_attrs, field.source || field.name)
    detected = infer_field_type(ash_attr, ui_defaults)

    nested_fields =
      maybe_infer_nested_fields(detected, field.nested_fields, ash_attr, field.auto_fields)

    %{
      field
      | type: detected,
        type_module: MishkaGervaz.Form.Types.Field.get_or_passthrough(detected),
        options: maybe_infer_options(detected, field.options, ash_attr),
        nested_fields: nested_fields,
        ui: maybe_inject_nested_ui_extras(field.ui, detected, nested_fields, ash_attr)
    }
  end

  defp maybe_resolve_field_type(%Field{type: :nested} = field, ash_attrs, _ui_defaults) do
    ash_attr = Map.get(ash_attrs, field.source || field.name)

    nested_fields =
      maybe_infer_nested_fields(:nested, field.nested_fields, ash_attr, field.auto_fields)

    case nested_fields do
      [] ->
        field

      _ ->
        %{
          field
          | nested_fields: nested_fields,
            ui: maybe_inject_nested_ui_extras(field.ui, :nested, nested_fields, ash_attr)
        }
    end
  end

  defp maybe_resolve_field_type(
         %Field{type: :select, options: nil} = field,
         ash_attrs,
         _ui_defaults
       ) do
    Map.get(ash_attrs, field.source || field.name)
    |> extract_one_of_options()
    |> case do
      nil -> field
      options -> %{field | options: options}
    end
  end

  defp maybe_resolve_field_type(field, _ash_attrs, _ui_defaults), do: field

  @spec maybe_inject_nested_ui_extras(Field.Ui.t() | nil, atom(), list(), map() | nil) ::
          Field.Ui.t() | nil
  defp maybe_inject_nested_ui_extras(field_ui, :nested, [_ | _] = _nested_fields, ash_attr) do
    base_ui = normalize_ui(field_ui)

    extra =
      (base_ui.extra || %{})
      |> Map.put(:nested_mode, detect_nested_mode(ash_attr))
      |> Map.put(:nested_source, detect_nested_source(ash_attr))

    %{base_ui | extra: extra}
  end

  defp maybe_inject_nested_ui_extras(field_ui, _detected, _nested_fields, _ash_attr), do: field_ui

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
      label = attr.name |> to_string() |> String.replace("_", " ") |> String.capitalize()

      %{
        name: attr.name,
        type: infer_field_type(%{type: attr.type, constraints: attr.constraints}, ui_defaults),
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
        label = humanize_name(field_name)

        %{
          name: field_name,
          type: constraint_type_to_field_type(field_type),
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
        Enum.find(inferred, &(&1.name == nf.name))
        |> then(&resolve_nested_field(nf, &1))
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
    dsl_state
    |> get_entities(@fields_path)
    |> filter_fields()
    |> Enum.reduce(dsl_state, fn
      %Field{source: nil, name: name} = field, acc ->
        Transformer.replace_entity(acc, @fields_path, %{field | source: name})

      _field, acc ->
        acc
    end)
  end

  @spec resolve_relation_resources(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_relation_resources(dsl_state) do
    relationships = get_relationships(dsl_state)

    dsl_state
    |> get_entities(@fields_path)
    |> filter_fields()
    |> Enum.reduce(dsl_state, fn field, acc ->
      case maybe_resolve_relation_resource(field, relationships) do
        nil -> acc
        resource -> Transformer.replace_entity(acc, @fields_path, %{field | resource: resource})
      end
    end)
  end

  @spec maybe_resolve_relation_resource(Field.t(), [map()]) :: module() | nil
  defp maybe_resolve_relation_resource(
         %Field{type: :relation, resource: nil} = field,
         relationships
       ),
       do: resolve_related_resource(field, relationships)

  defp maybe_resolve_relation_resource(_field, _relationships), do: nil

  defp resolve_related_resource(%Field{} = field, relationships) do
    field_name = field.source || field.name

    case Enum.find(relationships, &(&1.source_attribute == field_name)) do
      %{destination: dest} -> dest
      _ -> nil
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

    field_order
    |> Enum.map(fn name -> Enum.find(in_order, &(&1.name == name)) end)
    |> Enum.reject(&is_nil/1)
    |> Kernel.++(not_in_order)
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
    rel_names = dsl_state |> get_relationships() |> MapSet.new(& &1.name)

    preloads =
      dsl_state
      |> get_entities(@fields_path)
      |> filter_fields()
      |> Enum.filter(
        &(&1.type in [:relation, :select] and not is_nil(&1.resource) and not &1.virtual)
      )
      |> Enum.map(& &1.source)
      |> Enum.filter(&(&1 in rel_names))
      |> Enum.uniq()

    Transformer.persist(dsl_state, :mishka_gervaz_form_detected_preloads, preloads)
  end
end

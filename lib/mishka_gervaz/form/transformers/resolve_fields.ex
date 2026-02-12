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

      %Field{
        name: attr_name,
        source: attr_name,
        type: (override && override.type) || detected_type,
        required: default_if_nil(override && override.required, defaults.required),
        visible: default_if_nil(override && override.visible, defaults.visible),
        readonly: default_if_nil(override && override.readonly, defaults.readonly),
        format: override && override.format,
        ui: override && override.ui
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
        :json

      type == Ash.Type.UUID or type == Ash.Type.UUIDv7 ->
        :hidden

      type == Ash.Type.String ->
        infer_string_type(constraints, ui_defaults)

      match?({:array, _}, type) ->
        infer_array_type(type)

      true ->
        :text
    end
  end

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
  defp infer_array_type(_), do: :json

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

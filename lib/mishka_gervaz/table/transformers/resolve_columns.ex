defmodule MishkaGervaz.Table.Transformers.ResolveColumns do
  @moduledoc """
  Resolves column configurations from the DSL.

  This transformer:

  - Processes `auto_columns` to discover columns from Ash resource attributes
  - Resolves column positions (`:first`, `:last`, `{:before, :col}`, `{:after, :col}`)
  - Applies column order from `column_order` option
  - Infers column sources if not explicitly specified
  - Detects required preloads from relationship sources
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  alias MishkaGervaz.Table.Entities.Column
  alias MishkaGervaz.Table.Entities.AutoColumns
  import MishkaGervaz.Table.Transformers.Helpers

  @columns_path [:mishka_gervaz, :table, :columns]

  @impl true
  @spec after?(module()) :: boolean()
  def after?(MishkaGervaz.Table.Transformers.MergeDefaults), do: true
  def after?(Ash.Resource.Transformers.SetTypes), do: true
  def after?(_), do: false

  @impl true
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)

    dsl_state =
      dsl_state
      |> resolve_auto_columns(module)
      |> resolve_column_sources()
      |> resolve_column_positions()
      |> detect_preloads()

    {:ok, dsl_state}
  end

  @spec filter_columns([struct()]) :: [Column.t()]
  defp filter_columns(entities),
    do: Enum.filter(entities, &match?(%Column{}, &1))

  @spec resolve_auto_columns(Spark.Dsl.t(), module()) :: Spark.Dsl.t()
  defp resolve_auto_columns(dsl_state, _module) do
    entities = get_entities(dsl_state, @columns_path)

    case Enum.find(entities, &match?(%AutoColumns{}, &1)) do
      nil -> dsl_state
      config -> process_auto_columns(dsl_state, entities, config)
    end
  end

  @spec process_auto_columns(Spark.Dsl.t(), [struct()], AutoColumns.t()) :: Spark.Dsl.t()
  defp process_auto_columns(dsl_state, entities, config) do
    explicit = filter_columns(entities)

    new_columns =
      explicit
      |> Enum.map(& &1.name)
      |> then(&discover_columns(dsl_state, config, &1))
      |> build_auto_columns(config)

    dsl_state
    |> remove_all_column_entities(entities)
    |> add_column_entities(combine_columns(config.position, new_columns, explicit))
  end

  @spec combine_columns(:start | :end, [Column.t()], [Column.t()]) :: [Column.t()]
  defp combine_columns(:start, new, explicit), do: new ++ explicit
  defp combine_columns(:end, new, explicit), do: explicit ++ new

  @spec discover_columns(Spark.Dsl.t(), AutoColumns.t(), [atom()]) :: [atom()]
  defp discover_columns(dsl_state, config, explicit_columns) do
    names = get_attribute_names(dsl_state)

    if config.only do
      Enum.filter(names, &(&1 in config.only))
    else
      Enum.reject(names, &(&1 in config.except))
    end
    |> Enum.reject(&(&1 in explicit_columns))
  end

  @spec get_attribute_names(Spark.Dsl.t()) :: [atom()]
  defp get_attribute_names(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:attributes])
    |> Enum.map(& &1.name)
  rescue
    _ -> []
  end

  @spec build_auto_columns([atom()], AutoColumns.t()) :: [Column.t()]
  defp build_auto_columns(discovered, config) do
    defaults = extract_defaults(config.defaults)

    Enum.map(discovered, fn attr_name ->
      override = Enum.find(config.overrides || [], &(&1.name == attr_name))

      %Column{
        name: attr_name,
        source: attr_name,
        sortable: default_if_nil(override && override.sortable, defaults.sortable),
        searchable: default_if_nil(override && override.searchable, defaults.searchable),
        visible: default_if_nil(override && override.visible, defaults.visible),
        export: default_if_nil(override && override.export, defaults.export),
        format: override && override.format,
        ui: override && override.ui
      }
    end)
  end

  @spec extract_defaults(list() | struct() | nil) :: AutoColumns.Defaults.t()
  defp extract_defaults([d | _]), do: d
  defp extract_defaults(d) when is_struct(d), do: d
  defp extract_defaults(_), do: %AutoColumns.Defaults{}

  @spec remove_all_column_entities(Spark.Dsl.t(), [struct()]) :: Spark.Dsl.t()
  defp remove_all_column_entities(dsl_state, entities) do
    Enum.reduce(entities, dsl_state, fn entity, acc ->
      cond do
        match?(%Column{}, entity) ->
          Transformer.remove_entity(acc, @columns_path, &(&1 == entity))

        match?(%AutoColumns{}, entity) ->
          Transformer.remove_entity(acc, @columns_path, &match?(%AutoColumns{}, &1))

        true ->
          acc
      end
    end)
  end

  @spec add_column_entities(Spark.Dsl.t(), [Column.t()]) :: Spark.Dsl.t()
  defp add_column_entities(dsl_state, columns) do
    Enum.reduce(columns, dsl_state, fn col, acc ->
      Transformer.add_entity(acc, @columns_path, col, type: :append)
    end)
  end

  @spec resolve_column_sources(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_column_sources(dsl_state) do
    entities = get_entities(dsl_state, @columns_path)

    updated =
      Enum.map(entities, fn
        %Column{source: nil, name: name} = col -> %{col | source: name}
        other -> other
      end)

    dsl_state
    |> remove_column_entities(entities)
    |> add_column_entities(Enum.filter(updated, &match?(%Column{}, &1)))
  end

  @spec remove_column_entities(Spark.Dsl.t(), [struct()]) :: Spark.Dsl.t()
  defp remove_column_entities(dsl_state, entities) do
    Enum.reduce(entities, dsl_state, fn entity, acc ->
      if match?(%Column{}, entity) do
        Transformer.remove_entity(acc, @columns_path, &(&1.name == entity.name))
      else
        acc
      end
    end)
  end

  @spec resolve_column_positions(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp resolve_column_positions(dsl_state) do
    column_order = get_opt(dsl_state, @columns_path, :column_order)

    sorted_names =
      get_entities(dsl_state, @columns_path)
      |> filter_columns()
      |> sort_columns(column_order)
      |> Enum.map(& &1.name)

    Transformer.persist(dsl_state, :mishka_gervaz_column_order, sorted_names)
  end

  @spec sort_columns([Column.t()], [atom()] | nil) :: [Column.t()]
  defp sort_columns(columns, nil) do
    columns
    |> Enum.with_index()
    |> Enum.sort_by(fn {col, idx} -> position_sort_key(col.position, idx) end)
    |> Enum.map(&elem(&1, 0))
  end

  defp sort_columns(columns, column_order) do
    {in_order, not_in_order} = Enum.split_with(columns, &(&1.name in column_order))

    ordered =
      column_order
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
      |> get_entities(@columns_path)
      |> filter_columns()
      |> Enum.flat_map(&extract_preloads(&1.source))
      |> Enum.uniq()

    Transformer.persist(dsl_state, :mishka_gervaz_detected_preloads, preloads)
  end

  @spec extract_preloads(atom() | list() | {atom(), atom()} | term()) :: [atom()]
  defp extract_preloads(source) when is_atom(source), do: []

  defp extract_preloads(source) when is_list(source),
    do: Enum.flat_map(source, &extract_preloads/1)

  defp extract_preloads({rel, _field}) when is_atom(rel), do: [rel]
  defp extract_preloads(_), do: []
end

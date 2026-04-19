defmodule MishkaGervaz.Table.Verifiers.ValidateFilters do
  @moduledoc """
  Validates the filters section of MishkaGervaz DSL.

  Ensures:
  - When filters section exists, at least one filter is defined
  - Dependent filters reference existing filters
  - Relation filters with `:static` mode don't target resources with required pagination
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.{Filter, FilterGroup}
  @path [:mishka_gervaz, :table, :filters]
  @groups_path [:mishka_gervaz, :table, :filter_groups]

  @impl true
  def verify(dsl_state) do
    if is_nil(Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :identity], :route)) do
      :ok
    else
      do_verify(dsl_state)
    end
  end

  defp do_verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    filters =
      dsl_state
      |> Verifier.get_entities(@path)
      |> List.wrap()
      |> Enum.filter(&match?(%Filter{}, &1))

    filter_names = Enum.map(filters, & &1.name)

    filter_groups =
      dsl_state
      |> Verifier.get_entities(@groups_path)
      |> List.wrap()
      |> Enum.filter(&match?(%FilterGroup{}, &1))

    section_defined? = filters != []

    with :ok <- validate_at_least_one_filter(section_defined?, filters, dsl_state),
         :ok <- validate_dependencies(filters, filter_names, dsl_state),
         :ok <- validate_static_relation_pagination(filters, module),
         :ok <- validate_function_display_field_requires_search_field(filters, module),
         :ok <- validate_filter_groups(filter_groups, filter_names, dsl_state),
         do: :ok
  end

  @spec validate_at_least_one_filter(boolean(), list(), Spark.Dsl.t()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_at_least_one_filter(false, _filters, _dsl_state), do: :ok

  defp validate_at_least_one_filter(true, [], dsl_state) do
    {:error,
     Spark.Error.DslError.exception(
       module: Verifier.get_persisted(dsl_state, :module),
       path: @path,
       message: """
       filters section requires at least one filter.

       Example:
         filters do
           filter :search, :text do
             fields [:name, :email]
           end
         end
       """
     )}
  end

  defp validate_at_least_one_filter(true, _filters, _dsl_state), do: :ok

  @spec validate_dependencies(list(), list(), Spark.Dsl.t()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_dependencies(filters, filter_names, dsl_state) do
    invalid_deps =
      filters
      |> Enum.filter(fn f -> f.depends_on && f.depends_on not in filter_names end)
      |> Enum.map(fn f -> {f.name, f.depends_on} end)

    if invalid_deps == [] do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: @path,
         message: "Filters depend on non-existent filters: #{inspect(invalid_deps)}"
       )}
    end
  end

  @spec validate_static_relation_pagination(list(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_static_relation_pagination(filters, table_module) do
    static_relation_filters =
      filters
      |> Enum.filter(fn f ->
        f.type == :relation and (f.mode == :static or f.mode == nil)
      end)

    invalid_filters =
      Enum.filter(static_relation_filters, fn filter ->
        resource = resolve_related_resource(filter, table_module)
        action_name = filter.load_action || :read

        resource && has_required_pagination?(resource, action_name)
      end)

    case invalid_filters do
      [] ->
        :ok

      [filter | _] = all_invalid ->
        filter_names = Enum.map_join(all_invalid, ", ", &inspect(&1.name))

        {:error,
         Spark.Error.DslError.exception(
           module: table_module,
           path: @path,
           message: """
           Relation filter #{inspect(filter.name)} uses :static mode but the target resource's \
           action has required pagination (required?: true).

           Static mode uses `page: false` to load all options at once, which is incompatible \
           with required pagination.

           Invalid filters: #{filter_names}

           Solutions:
           1. Change the filter mode to :load_more, :search, or :search_multi:

              filter #{inspect(filter.name)}, type: :relation do
                mode :load_more  # or :search, :search_multi
              end

           2. Or modify the target resource's action to use optional pagination:

              read :read do
                pagination offset?: true, countable: true, required?: false
              end
           """
         )}
    end
  end

  @spec resolve_related_resource(Filter.t(), module()) :: module() | nil
  defp resolve_related_resource(%{resource: resource}, _) when not is_nil(resource), do: resource

  defp resolve_related_resource(%{name: name, source: source}, table_module) do
    field_name = source || name

    table_module
    |> Ash.Resource.Info.relationships()
    |> Enum.find(&(&1.source_attribute == field_name))
    |> case do
      %{destination: dest} -> dest
      nil -> nil
    end
  rescue
    _ -> nil
  end

  @spec has_required_pagination?(module(), atom()) :: boolean()
  defp has_required_pagination?(resource, action_name) do
    case Ash.Resource.Info.action(resource, action_name) do
      %{pagination: pagination} when not is_nil(pagination) ->
        pagination_required?(pagination)

      _ ->
        false
    end
  rescue
    _ -> false
  end

  @spec pagination_required?(map() | Keyword.t()) :: boolean()
  defp pagination_required?(pagination) when is_map(pagination) do
    has_pagination? =
      Map.get(pagination, :offset?) == true or Map.get(pagination, :keyset?) == true

    required? = Map.get(pagination, :required?, true)

    has_pagination? and required?
  end

  defp pagination_required?(pagination) when is_list(pagination) do
    has_pagination? =
      Keyword.get(pagination, :offset?) == true or Keyword.get(pagination, :keyset?) == true

    required? = Keyword.get(pagination, :required?, true)

    has_pagination? and required?
  end

  defp pagination_required?(_), do: false

  @spec validate_function_display_field_requires_search_field(list(), module()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_function_display_field_requires_search_field(filters, table_module) do
    invalid_filters =
      Enum.filter(filters, fn filter ->
        filter.type == :relation and
          is_function(filter.display_field, 1) and
          is_nil(filter.search_field)
      end)

    case invalid_filters do
      [] ->
        :ok

      [filter | _] = all_invalid ->
        filter_names = Enum.map_join(all_invalid, ", ", &inspect(&1.name))

        {:error,
         Spark.Error.DslError.exception(
           module: table_module,
           path: @path,
           message: """
           Relation filter #{inspect(filter.name)} uses a function for display_field but \
           search_field is not set.

           When display_field is a function, you must explicitly set search_field since \
           a function cannot be used for searching.

           Invalid filters: #{filter_names}

           Solution:
             filter #{inspect(filter.name)}, :relation do
               display_field fn r -> "\#{r.name} - \#{r.site.name}" end
               search_field :name  # Required when display_field is a function
             end
           """
         )}
    end
  end

  @spec validate_filter_groups(list(), list(), Spark.Dsl.t()) ::
          :ok | {:error, Spark.Error.DslError.t()}
  defp validate_filter_groups([], _filter_names, _dsl_state), do: :ok

  defp validate_filter_groups(groups, filter_names, dsl_state) do
    with :ok <- validate_group_filters_exist(groups, filter_names, dsl_state),
         :ok <- validate_no_duplicate_filter_assignments(groups, dsl_state) do
      :ok
    end
  end

  defp validate_group_filters_exist(groups, filter_names, dsl_state) do
    invalid =
      Enum.flat_map(groups, fn group ->
        missing = Enum.reject(group.filters, &(&1 in filter_names))
        Enum.map(missing, &{group.name, &1})
      end)

    if invalid == [] do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: @groups_path,
         message: """
         Filter groups reference non-existent filters: #{inspect(invalid)}

         Each filter in a group must be defined in the filters section.
         """
       )}
    end
  end

  defp validate_no_duplicate_filter_assignments(groups, dsl_state) do
    all_assigned =
      Enum.flat_map(groups, fn group ->
        Enum.map(group.filters, &{&1, group.name})
      end)

    duplicates =
      all_assigned
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.filter(fn {_name, assignments} -> length(assignments) > 1 end)
      |> Enum.map(fn {name, assignments} ->
        groups = Enum.map(assignments, &elem(&1, 1))
        {name, groups}
      end)

    if duplicates == [] do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: @groups_path,
         message: """
         Filters assigned to multiple groups: #{inspect(duplicates)}

         Each filter can only belong to one group.
         """
       )}
    end
  end
end

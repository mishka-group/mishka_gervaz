defmodule MishkaGervaz.Table.Web.DataLoader.RelationLoader do
  @moduledoc """
  Handles paginated loading of relation filter options.

  Provides support for different loading modes:
  - `:static` - Load all options at once
  - `:load_more` - Initial page with load more capability
  - `:search` - Search with pagination (single select)
  - `:search_multi` - Search with pagination (multi select)

  ## Usage

      # Load initial options
      {:ok, result} = RelationLoader.load_options(filter, state, page: 1)

      # Search options
      {:ok, result} = RelationLoader.search_options(filter, state, "search term", page: 1)

  ## Override

      defmodule MyApp.Table.RelationLoader do
        use MishkaGervaz.Table.Web.DataLoader.RelationLoader

        def load_options(filter, state, opts) do
          # Custom loading logic
          super(filter, state, opts)
        end
      end
  """

  @type load_result :: %{
          options: list({String.t(), any()}),
          page: pos_integer(),
          has_more?: boolean(),
          total_count: pos_integer() | nil
        }

  @type filter :: map()
  @type state :: map()

  @callback load_options(filter(), state(), keyword()) :: {:ok, load_result()} | {:error, term()}
  @callback search_options(filter(), state(), String.t(), keyword()) ::
              {:ok, load_result()} | {:error, term()}
  @callback load_more_options(filter(), state(), keyword()) ::
              {:ok, load_result()} | {:error, term()}
  @callback resolve_selected(filter(), state(), list()) ::
              {:ok, list({String.t(), any()})} | {:error, term()}
  @callback load_with_selected(filter(), state(), list(), keyword()) ::
              {:ok, load_result()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.DataLoader.RelationLoader
      require Ash.Query

      @impl true
      @spec load_options(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
      def load_options(filter, state, opts \\ []) do
        page = Keyword.get(opts, :page, 1)
        resource = resolve_resource(filter, state)
        display_field = resolve_display_field(filter, resource)

        case filter.mode do
          :static -> load_all_options(filter, state, resource, display_field)
          _ -> load_paginated_options(filter, state, resource, display_field, page, nil)
        end
      end

      @impl true
      @spec search_options(map(), map(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
      def search_options(filter, state, search_term, opts \\ []) do
        page = Keyword.get(opts, :page, 1)
        resource = resolve_resource(filter, state)
        display_field = resolve_display_field(filter, resource)

        search_field =
          cond do
            filter[:search_field] -> filter[:search_field]
            is_atom(display_field) -> display_field
            true -> :name
          end

        load_paginated_options(
          filter,
          state,
          resource,
          display_field,
          page,
          {search_field, search_term}
        )
      end

      @impl true
      @spec load_more_options(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
      def load_more_options(filter, state, opts \\ []) do
        page = Keyword.get(opts, :page, 1)
        resource = resolve_resource(filter, state)
        display_field = resolve_display_field(filter, resource)

        load_paginated_options(filter, state, resource, display_field, page, nil)
      end

      @impl true
      @spec resolve_selected(map(), map(), list()) ::
              {:ok, list({String.t(), any()})} | {:error, term()}
      def resolve_selected(_filter, _state, []), do: {:ok, []}
      def resolve_selected(_filter, _state, nil), do: {:ok, []}

      def resolve_selected(filter, state, selected_ids) when is_list(selected_ids) do
        {nil_selected, real_ids} =
          Enum.split_with(selected_ids, &(&1 == "__nil__" or &1 == :nil_value))

        resource = resolve_resource(filter, state)
        display_field = resolve_display_field(filter, resource)
        action = resolve_load_action(filter, state, resource)
        actor = state.current_user
        tenant = get_tenant(state)

        nil_options = if nil_selected != [], do: get_nil_option(filter), else: []

        case real_ids do
          [] ->
            {:ok, nil_options}

          ids ->
            query =
              resource
              |> Ash.Query.new()
              |> Ash.Query.filter_input(%{id: %{in: ids}})
              |> maybe_apply_custom_load(filter, state)

            opts = [action: action, actor: actor, authorize?: false, page: false]
            opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

            case Ash.read(query, opts) do
              {:ok, records} ->
                options =
                  Enum.map(records, fn record ->
                    {get_display_value(record, display_field, state), to_string(record.id)}
                  end)

                {:ok, nil_options ++ options}

              {:error, %Ash.Error.Invalid{errors: errors}} = error ->
                has_pagination_error =
                  Enum.any?(errors, fn
                    %Ash.Error.Invalid.PaginationRequired{} -> true
                    _ -> false
                  end)

                if has_pagination_error do
                  preloads = build_preloads_list(filter, state)
                  get_opts = [action: action, actor: actor, authorize?: false, load: preloads]
                  get_opts = if tenant, do: Keyword.put(get_opts, :tenant, tenant), else: get_opts

                  options =
                    ids
                    |> Enum.map(fn id ->
                      case Ash.get(resource, id, get_opts) do
                        {:ok, record} ->
                          {get_display_value(record, display_field, state), to_string(record.id)}

                        _ ->
                          nil
                      end
                    end)
                    |> Enum.reject(&is_nil/1)

                  {:ok, nil_options ++ options}
                else
                  error
                end

              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      @impl true
      @spec load_with_selected(map(), map(), list(), keyword()) :: {:ok, map()} | {:error, term()}
      def load_with_selected(filter, state, selected_ids, opts \\ []) do
        with {:ok, selected_options} <- resolve_selected(filter, state, selected_ids),
             {:ok, result} <- load_options(filter, state, opts) do
          selected_values = Enum.map(selected_options, fn {_, v} -> v end)

          filtered_options =
            Enum.reject(result.options, fn {_, v} -> to_string(v) in selected_values end)

          merged_options = selected_options ++ filtered_options

          {:ok, %{result | options: merged_options}}
        end
      end

      @spec get_nil_option(map()) :: list({String.t(), String.t()})
      defp get_nil_option(%{include_nil: label}) when is_binary(label), do: [{label, "__nil__"}]
      defp get_nil_option(%{include_nil: true}), do: [{"(None)", "__nil__"}]
      defp get_nil_option(_), do: []

      @spec load_all_options(map(), map(), module(), atom() | (struct() -> String.t())) ::
              {:ok, map()} | {:error, term()}
      defp load_all_options(filter, state, resource, display_field) do
        action = resolve_load_action(filter, state, resource)
        actor = state.current_user
        tenant = get_tenant(state)

        query =
          resource
          |> Ash.Query.new()
          |> maybe_apply_custom_load(filter, state)

        opts = [action: action, actor: actor, authorize?: false, page: false]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case Ash.read(query, opts) do
          {:ok, records} ->
            options = build_options(records, display_field, filter[:include_nil], state)
            {:ok, %{options: options, page: 1, has_more?: false, total_count: length(records)}}

          {:error, reason} ->
            {:error, reason}
        end
      end

      @spec load_paginated_options(
              map(),
              map(),
              module(),
              atom() | (struct() -> String.t()),
              pos_integer(),
              tuple() | nil
            ) :: {:ok, map()} | {:error, term()}
      defp load_paginated_options(filter, state, resource, display_field, page, search) do
        actor = state.current_user
        tenant = get_tenant(state)
        page_size = filter[:page_size] || 20

        action = resolve_load_action(filter, state, resource)

        query =
          resource
          |> Ash.Query.new()
          |> maybe_apply_search(search)
          |> maybe_apply_custom_load(filter, state)

        page_opts = [limit: page_size + 1, offset: (page - 1) * page_size]

        opts = [action: action, actor: actor, authorize?: false, page: page_opts]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case Ash.read(query, opts) do
          {:ok, %{results: records} = page_result} ->
            has_more? = length(records) > page_size
            actual_records = if has_more?, do: Enum.take(records, page_size), else: records
            include_nil = if page == 1, do: filter[:include_nil], else: false
            options = build_options(actual_records, display_field, include_nil, state)

            {:ok,
             %{
               options: options,
               page: page,
               has_more?: has_more?,
               total_count: Map.get(page_result, :count)
             }}

          {:ok, records} when is_list(records) ->
            has_more? = length(records) > page_size
            actual_records = if has_more?, do: Enum.take(records, page_size), else: records
            include_nil = if page == 1, do: filter[:include_nil], else: false
            options = build_options(actual_records, display_field, include_nil, state)

            {:ok, %{options: options, page: page, has_more?: has_more?, total_count: nil}}

          {:error, reason} ->
            {:error, reason}
        end
      end

      @spec maybe_apply_search(Ash.Query.t(), tuple() | nil) :: Ash.Query.t()
      defp maybe_apply_search(query, nil), do: query

      defp maybe_apply_search(query, {field, term}) when is_binary(term) and term != "" do
        Ash.Query.filter(query, contains(^Ash.Expr.ref(field), ^term))
      end

      defp maybe_apply_search(query, _), do: query

      @spec maybe_apply_custom_load(Ash.Query.t(), map(), map()) :: Ash.Query.t()
      defp maybe_apply_custom_load(query, %{load: load_fn} = filter, state)
           when is_function(load_fn, 2) do
        query
        |> load_fn.(state)
        |> maybe_apply_preloads(filter, state)
      end

      defp maybe_apply_custom_load(query, filter, state) do
        maybe_apply_preloads(query, filter, state)
      end

      @spec maybe_apply_preloads(Ash.Query.t(), map(), map()) :: Ash.Query.t()
      defp maybe_apply_preloads(query, %{preload: preload}, state) when is_struct(preload) do
        preloads = build_preloads(preload, state)
        if preloads == [], do: query, else: Ash.Query.load(query, preloads)
      end

      defp maybe_apply_preloads(query, %{preload: [preload_struct | _]}, state)
           when is_struct(preload_struct) do
        preloads = build_preloads(preload_struct, state)
        if preloads == [], do: query, else: Ash.Query.load(query, preloads)
      end

      defp maybe_apply_preloads(query, _, _), do: query

      @spec build_preloads(struct(), map()) :: list()
      defp build_preloads(preload, state) do
        always = preload.always || []
        user_specific = if state.master_user?, do: preload.master, else: preload.tenant
        user_specific = user_specific || []

        (always ++ user_specific)
        |> List.flatten()
        |> Enum.uniq()
      end

      @spec build_preloads_list(map(), map()) :: list()
      defp build_preloads_list(%{preload: preload}, state) when is_struct(preload) do
        build_preloads(preload, state)
      end

      defp build_preloads_list(%{preload: [preload_struct | _]}, state)
           when is_struct(preload_struct) do
        build_preloads(preload_struct, state)
      end

      defp build_preloads_list(_, _), do: []

      @spec build_options(
              list(struct()),
              atom() | (struct() -> String.t()) | (struct(), map() -> String.t()),
              boolean() | String.t() | nil,
              map()
            ) :: list({String.t(), String.t()})
      defp build_options(records, display_field, include_nil, state) do
        base_options =
          Enum.map(records, fn record ->
            label = get_display_value(record, display_field, state)
            {label, to_string(record.id)}
          end)

        prepend_nil_option(base_options, include_nil)
      end

      @spec prepend_nil_option(list(), boolean() | String.t() | nil) :: list()
      defp prepend_nil_option(options, nil), do: options
      defp prepend_nil_option(options, false), do: options
      defp prepend_nil_option(options, true), do: [{"(None)", "__nil__"} | options]

      defp prepend_nil_option(options, label) when is_binary(label) do
        [{label, "__nil__"} | options]
      end

      @spec get_display_value(
              struct(),
              atom() | (struct() -> String.t()) | (struct(), map() -> String.t()),
              map()
            ) ::
              String.t()
      defp get_display_value(record, display_field, state) do
        MishkaGervaz.Helpers.resolve_label(record, display_field, state)
      end

      @spec resolve_resource(map(), map()) :: module()
      defp resolve_resource(%{resource: resource}, _state) when not is_nil(resource), do: resource

      defp resolve_resource(%{name: name, source: source}, %{static: %{resource: table_resource}}) do
        field_name = source || name
        relationships = Ash.Resource.Info.relationships(table_resource)

        case Enum.find(relationships, &(&1.source_attribute == field_name)) do
          %{destination: dest} -> dest
          nil -> raise "Cannot resolve resource for filter #{name}"
        end
      end

      @spec resolve_display_field(map(), module()) ::
              atom() | (struct() -> String.t()) | (struct(), map() -> String.t())
      defp resolve_display_field(%{display_field: field}, _resource)
           when is_function(field, 1) or is_function(field, 2) or
                  (is_atom(field) and not is_nil(field)) do
        field
      end

      defp resolve_display_field(_filter, resource) do
        attrs = Ash.Resource.Info.attributes(resource)

        Enum.find_value([:name, :title, :label], :id, fn field ->
          if Enum.any?(attrs, &(&1.name == field)), do: field
        end)
      end

      @spec get_tenant(map()) :: any()
      defp get_tenant(%{master_user?: true}), do: nil
      defp get_tenant(%{current_user: user}), do: Map.get(user, :site_id)
      defp get_tenant(_), do: nil

      @spec resolve_load_action(map(), map(), module()) :: atom()
      defp resolve_load_action(
             %{load_action: {master_action, _tenant_action}},
             %{master_user?: true},
             _resource
           ) do
        master_action
      end

      defp resolve_load_action(%{load_action: {_master_action, tenant_action}}, _state, _resource) do
        tenant_action
      end

      defp resolve_load_action(%{load_action: :read}, %{master_user?: true}, resource) do
        actions = Ash.Resource.Info.actions(resource)

        cond do
          Enum.any?(actions, &(&1.name == :master_read)) -> :master_read
          Enum.any?(actions, &(&1.name == :read_any)) -> :read_any
          true -> :read
        end
      end

      defp resolve_load_action(%{load_action: action}, _state, _resource)
           when is_atom(action) and not is_nil(action) do
        action
      end

      defp resolve_load_action(_filter, %{master_user?: true}, resource) do
        actions = Ash.Resource.Info.actions(resource)

        cond do
          Enum.any?(actions, &(&1.name == :master_read)) -> :master_read
          Enum.any?(actions, &(&1.name == :read_any)) -> :read_any
          true -> :read
        end
      end

      defp resolve_load_action(_filter, _state, _resource) do
        :read
      end

      defoverridable load_options: 2,
                     load_options: 3,
                     search_options: 3,
                     search_options: 4,
                     load_more_options: 2,
                     load_more_options: 3,
                     resolve_selected: 3,
                     load_with_selected: 3,
                     load_with_selected: 4
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.RelationLoader.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.RelationLoader
end

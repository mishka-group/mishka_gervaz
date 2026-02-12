defmodule MishkaGervaz.Form.Web.DataLoader.RelationLoader do
  @moduledoc """
  Loads options for relation/select fields in forms.

  Follows the same pattern as `MishkaGervaz.Table.Web.DataLoader.RelationLoader`.

  ## Modes

  - `:static` - Load all options at once (`page: false`)
  - `:load_more` - Paginated with load more button
  - `:search` - Search with pagination (single select)
  - `:search_multi` - Search with pagination (multi select)

  ## Action Resolution

  For master users, tries `:master_read` → `:read_any` → `:read`.
  For tenant users, uses `:read` with the user's `site_id` as tenant.

  ## User Override

      defmodule MyApp.Form.RelationLoader do
        use MishkaGervaz.Form.Web.DataLoader.RelationLoader

        def load_options(field, state, opts) do
          super(field, state, opts)
        end
      end
  """

  alias MishkaGervaz.Form.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.DataLoader.Builder

      alias MishkaGervaz.Form.Web.State
      require Ash.Query

      # --- Public API ---

      @spec load_options(map(), State.t(), keyword()) ::
              {:ok, list({String.t(), String.t()}), boolean()} | {:error, term()}
      def load_options(field, state, opts \\ []) do
        resource = Map.get(field, :resource)

        case resource do
          nil ->
            {:ok, Map.get(field, :options) || [], false}

          resource when is_atom(resource) ->
            page = Keyword.get(opts, :page, 1)
            display_field = resolve_display_field(field, resource)

            case Map.get(field, :mode, :static) do
              :static -> load_all_options(field, state, resource, display_field)
              _ -> load_paginated_options(field, state, resource, display_field, page, nil)
            end
        end
      end

      @spec search_options(map(), State.t(), String.t(), keyword()) ::
              {:ok, list({String.t(), String.t()}), boolean()} | {:error, term()}
      def search_options(field, state, search_term, opts \\ []) do
        resource = Map.get(field, :resource)

        case resource do
          nil ->
            static_options = Map.get(field, :options) || []

            filtered =
              Enum.filter(static_options, fn {label, _} ->
                String.contains?(String.downcase(label), String.downcase(search_term))
              end)

            {:ok, filtered, false}

          resource when is_atom(resource) ->
            page = Keyword.get(opts, :page, 1)
            display_field = resolve_display_field(field, resource)

            search_field =
              cond do
                field[:search_field] -> field[:search_field]
                is_atom(display_field) -> display_field
                true -> :name
              end

            load_paginated_options(
              field,
              state,
              resource,
              display_field,
              page,
              {search_field, search_term}
            )
        end
      end

      @spec resolve_selected(map(), State.t(), list(String.t())) ::
              {:ok, list({String.t(), String.t()})} | {:error, term()}
      def resolve_selected(_field, _state, []), do: {:ok, []}
      def resolve_selected(_field, _state, nil), do: {:ok, []}

      def resolve_selected(field, state, selected_ids) when is_list(selected_ids) do
        resource = Map.get(field, :resource)
        display_field = resolve_display_field(field, resource)

        case resource do
          nil ->
            static_options = Map.get(field, :options) || []

            matched =
              Enum.filter(static_options, fn {_, value} ->
                to_string(value) in selected_ids
              end)

            {:ok, matched}

          resource when is_atom(resource) ->
            action = resolve_load_action(field, state, resource)
            tenant = get_tenant(state)

            query =
              resource
              |> Ash.Query.new()
              |> Ash.Query.filter_input(%{id: %{in: selected_ids}})

            opts = [action: action, actor: state.current_user, authorize?: false, page: false]
            opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

            case Ash.read(query, opts) do
              {:ok, records} ->
                matched =
                  Enum.map(records, fn record ->
                    {get_display_value(record, display_field), to_string(record.id)}
                  end)

                {:ok, matched}

              {:error, %Ash.Error.Invalid{errors: errors}} ->
                # Fallback to Ash.get per-id if pagination is required
                if Enum.any?(errors, &match?(%Ash.Error.Invalid.PaginationRequired{}, &1)) do
                  get_opts = [action: action, actor: state.current_user, authorize?: false]
                  get_opts = if tenant, do: Keyword.put(get_opts, :tenant, tenant), else: get_opts

                  matched =
                    selected_ids
                    |> Enum.map(fn id ->
                      case Ash.get(resource, id, get_opts) do
                        {:ok, record} ->
                          {get_display_value(record, display_field), to_string(record.id)}

                        _ ->
                          nil
                      end
                    end)
                    |> Enum.reject(&is_nil/1)

                  {:ok, matched}
                else
                  {:error, %Ash.Error.Invalid{errors: errors}}
                end

              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      # --- Private: load_all_options (static mode, page: false) ---

      defp load_all_options(field, state, resource, display_field) do
        action = resolve_load_action(field, state, resource)
        actor = state.current_user
        tenant = get_tenant(state)
        load_fn = Map.get(field, :load)

        query =
          resource
          |> Ash.Query.new()
          |> maybe_apply_custom_load(load_fn, state)

        opts = [action: action, actor: actor, authorize?: false, page: false]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case Ash.read(query, opts) do
          {:ok, records} ->
            options = build_options(records, display_field)
            {:ok, options, false}

          {:error, reason} ->
            {:error, reason}
        end
      end

      # --- Private: load_paginated_options (search/load_more modes) ---

      defp load_paginated_options(field, state, resource, display_field, page, search) do
        action = resolve_load_action(field, state, resource)
        actor = state.current_user
        tenant = get_tenant(state)
        page_size = Map.get(field, :page_size) || 20
        load_fn = Map.get(field, :load)

        query =
          resource
          |> Ash.Query.new()
          |> maybe_apply_search(search)
          |> maybe_apply_custom_load(load_fn, state)

        page_opts = [limit: page_size + 1, offset: (page - 1) * page_size]

        opts = [action: action, actor: actor, authorize?: false, page: page_opts]
        opts = if tenant, do: Keyword.put(opts, :tenant, tenant), else: opts

        case Ash.read(query, opts) do
          {:ok, %{results: records}} ->
            has_more? = length(records) > page_size
            actual = if has_more?, do: Enum.take(records, page_size), else: records
            options = build_options(actual, display_field)
            {:ok, options, has_more?}

          {:ok, records} when is_list(records) ->
            has_more? = length(records) > page_size
            actual = if has_more?, do: Enum.take(records, page_size), else: records
            options = build_options(actual, display_field)
            {:ok, options, has_more?}

          {:error, reason} ->
            {:error, reason}
        end
      end

      # --- Helpers ---

      defp build_options(records, display_field) do
        Enum.map(records, fn record ->
          {get_display_value(record, display_field), to_string(record.id)}
        end)
      end

      defp get_display_value(record, display_field) when is_atom(display_field) do
        to_string(Map.get(record, display_field, Map.get(record, :id)))
      end

      defp get_display_value(record, display_field) when is_function(display_field, 1) do
        display_field.(record)
      end

      defp get_display_value(record, _), do: to_string(record.id)

      defp resolve_display_field(%{display_field: field}, _resource)
           when is_function(field, 1) or (is_atom(field) and not is_nil(field)) do
        field
      end

      defp resolve_display_field(_field, resource) when is_atom(resource) and not is_nil(resource) do
        attrs = Ash.Resource.Info.attributes(resource)

        Enum.find_value([:name, :title, :label], :id, fn name ->
          if Enum.any?(attrs, &(&1.name == name)), do: name
        end)
      rescue
        _ -> :name
      end

      defp resolve_display_field(_, _), do: :name

      @spec maybe_apply_search(Ash.Query.t(), tuple() | nil) :: Ash.Query.t()
      defp maybe_apply_search(query, nil), do: query

      defp maybe_apply_search(query, {field, term}) when is_binary(term) and term != "" do
        Ash.Query.filter(query, contains(^Ash.Expr.ref(field), ^term))
      end

      defp maybe_apply_search(query, _), do: query

      defp maybe_apply_custom_load(query, nil, _state), do: query

      defp maybe_apply_custom_load(query, load_fn, state) when is_function(load_fn, 2) do
        load_fn.(query, state)
      end

      defp maybe_apply_custom_load(query, _load_fn, _state), do: query

      # --- Action resolution (matches table pattern exactly) ---

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

      defp resolve_load_action(_field, %{master_user?: true}, resource) do
        actions = Ash.Resource.Info.actions(resource)

        cond do
          Enum.any?(actions, &(&1.name == :master_read)) -> :master_read
          Enum.any?(actions, &(&1.name == :read_any)) -> :read_any
          true -> :read
        end
      end

      defp resolve_load_action(_field, _state, _resource), do: :read

      # --- Tenant resolution (matches table pattern) ---

      @spec get_tenant(map()) :: any()
      defp get_tenant(%{master_user?: true}), do: nil
      defp get_tenant(%{current_user: user}), do: Map.get(user, :site_id)
      defp get_tenant(_), do: nil

      defoverridable load_options: 2,
                     load_options: 3,
                     search_options: 3,
                     search_options: 4,
                     resolve_selected: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.DataLoader.RelationLoader.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.DataLoader.RelationLoader
end

defmodule MishkaGervaz.Form.Web.DataLoader.RelationLoader do
  @moduledoc """
  Loads options for relation/select fields in forms.

  Handles loading relationship data for select fields, search-selects,
  and other fields that need to present options from related resources.

  ## Overridable Functions

  - `load_options/3` - Load options for a relation field
  - `search_options/4` - Search options with a query string
  - `resolve_selected/3` - Resolve labels for pre-selected values

  ## User Override

      defmodule MyApp.Form.RelationLoader do
        use MishkaGervaz.Form.Web.DataLoader.RelationLoader

        def load_options(field, state, opts) do
          # Custom loading with caching
          super(field, state, opts)
        end
      end
  """

  alias MishkaGervaz.Form.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.DataLoader.Builder

      alias MishkaGervaz.Form.Web.State

      @doc """
      Load options for a relation field.

      Returns a list of `{label, value}` tuples.

      ## Options

      - `:page` - Page number (default: 1)
      - `:page_size` - Page size (default: 25)
      - `:tenant` - Tenant for scoping
      - `:actor` - Actor for authorization
      """
      @spec load_options(map(), State.t(), keyword()) ::
              {:ok, list({String.t(), String.t()}), boolean()} | {:error, term()}
      def load_options(field, state, opts \\ []) do
        page = Keyword.get(opts, :page, 1)
        page_size = Keyword.get(opts, :page_size, 25)
        actor = Keyword.get(opts, :actor, state.current_user)
        tenant = Keyword.get(opts, :tenant)

        source = Map.get(field, :source)
        display_field = Map.get(field, :display_field, :name)
        value_field = Map.get(field, :value_field, :id)

        case source do
          nil ->
            static_options = Map.get(field, :options, [])
            {:ok, static_options, false}

          resource when is_atom(resource) ->
            query_opts =
              [actor: actor, page: [limit: page_size + 1, offset: (page - 1) * page_size]]
              |> maybe_add_tenant(tenant)

            case Ash.read(resource, query_opts) do
              {:ok, results} ->
                has_more? = length(results) > page_size
                records = Enum.take(results, page_size)

                options =
                  Enum.map(records, fn record ->
                    label = to_string(Map.get(record, display_field, Map.get(record, :id)))
                    value = to_string(Map.get(record, value_field))
                    {label, value}
                  end)

                {:ok, options, has_more?}

              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      @doc """
      Search options with a query string.

      Filters relation options by matching the search term against the display field.
      """
      @spec search_options(map(), State.t(), String.t(), keyword()) ::
              {:ok, list({String.t(), String.t()}), boolean()} | {:error, term()}
      def search_options(field, state, search_term, opts \\ []) do
        page_size = Keyword.get(opts, :page_size, 25)
        actor = Keyword.get(opts, :actor, state.current_user)
        tenant = Keyword.get(opts, :tenant)

        source = Map.get(field, :source)
        display_field = Map.get(field, :display_field, :name)
        value_field = Map.get(field, :value_field, :id)

        case source do
          nil ->
            static_options = Map.get(field, :options, [])

            filtered =
              Enum.filter(static_options, fn {label, _} ->
                String.contains?(String.downcase(label), String.downcase(search_term))
              end)

            {:ok, filtered, false}

          resource when is_atom(resource) ->
            query_opts =
              [actor: actor, page: [limit: page_size + 1]]
              |> maybe_add_tenant(tenant)

            case Ash.read(resource, query_opts) do
              {:ok, results} ->
                filtered =
                  results
                  |> Enum.filter(fn record ->
                    label = to_string(Map.get(record, display_field, ""))
                    String.contains?(String.downcase(label), String.downcase(search_term))
                  end)
                  |> Enum.take(page_size)

                options =
                  Enum.map(filtered, fn record ->
                    label = to_string(Map.get(record, display_field, Map.get(record, :id)))
                    value = to_string(Map.get(record, value_field))
                    {label, value}
                  end)

                {:ok, options, false}

              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      @doc """
      Resolve labels for pre-selected IDs.

      Used when restoring form state (e.g., from URL params) where only IDs are known.
      """
      @spec resolve_selected(map(), State.t(), list(String.t())) ::
              {:ok, list({String.t(), String.t()})} | {:error, term()}
      def resolve_selected(field, state, selected_ids) when is_list(selected_ids) do
        source = Map.get(field, :source)
        display_field = Map.get(field, :display_field, :name)
        value_field = Map.get(field, :value_field, :id)

        case source do
          nil ->
            static_options = Map.get(field, :options, [])

            matched =
              Enum.filter(static_options, fn {_, value} ->
                to_string(value) in selected_ids
              end)

            {:ok, matched}

          resource when is_atom(resource) ->
            actor = state.current_user

            case Ash.read(resource, actor: actor) do
              {:ok, results} ->
                matched =
                  results
                  |> Enum.filter(fn record ->
                    to_string(Map.get(record, value_field)) in selected_ids
                  end)
                  |> Enum.map(fn record ->
                    label = to_string(Map.get(record, display_field, Map.get(record, :id)))
                    value = to_string(Map.get(record, value_field))
                    {label, value}
                  end)

                {:ok, matched}

              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      @spec maybe_add_tenant(keyword(), any()) :: keyword()
      defp maybe_add_tenant(opts, nil), do: opts
      defp maybe_add_tenant(opts, tenant), do: Keyword.put(opts, :tenant, tenant)

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

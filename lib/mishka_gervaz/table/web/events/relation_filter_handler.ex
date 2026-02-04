defmodule MishkaGervaz.Table.Web.Events.RelationFilterHandler do
  @moduledoc """
  Handles relation filter events for dynamic search, load more, and multi-select.

  This module manages server-side state for relation filters that need:
  - Async search with database queries
  - Paginated option loading
  - Multi-select with label resolution

  ## Events Handled

  - `search` - Search options by term (debounced)
  - `load_more` - Load next page of options
  - `focus` - Open dropdown and load initial options
  - `close_dropdown` - Close dropdown on click-away
  - `toggle` - Toggle selection in multi-select mode

  ## Public Validation Functions

  - `skip_relation_search_term?/2` - Check if a value should be skipped as a filter value
  - `valid_relation_value?/1` - Check if a value is a valid relation filter value (UUID or __nil__)

  ## Client-Side Alternative

  Users with custom JS comboboxes (Tom Select, Headless UI, etc.) can bypass
  these events entirely and just use the standard `"filter"` event to submit
  final selected values. These events are for server-managed UI state.

  ## Customization

  You can create a custom RelationFilterHandler:

      defmodule MyApp.CustomRelationFilterHandler do
        use MishkaGervaz.Table.Web.Events.RelationFilterHandler

        def handle("toggle", params, state, socket) do
          MyApp.Analytics.track("relation_filter_toggle", params)
          super("toggle", params, state, socket)
        end
      end

  Then configure it in your resource's DSL:

      mishka_gervaz do
        table do
          events do
            relation_filter MyApp.CustomRelationFilterHandler
          end
        end
      end
  """

  alias MishkaGervaz.Table.Web.{State, DataLoader}
  alias MishkaGervaz.Table.Web.DataLoader.RelationLoader

  @type state :: State.t()
  @type socket :: Phoenix.LiveView.Socket.t()
  @type params :: map()

  @callback handle(action :: String.t(), params :: params(), state :: state(), socket :: socket()) ::
              {:noreply, socket()}

  @doc """
  Checks if a relation filter value should be skipped (not treated as a filter value).

  For relation filters with `:search` or `:search_multi` mode, this returns `true`
  if the value is not valid for the filter's ID type - meaning it's likely a search
  term that should not be used as the actual filter value.

  The `id_type` is determined from the related resource's primary key type:
  - `:uuid` - Validates as UUID
  - `:uuid_v7` - Validates as UUID (same format)
  - `:integer` - Validates as integer
  - `:string` - Any non-empty string is valid

  ## Examples

      iex> skip_relation_search_term?(%{type: :relation, mode: :search, id_type: :uuid}, "some search text")
      true

      iex> skip_relation_search_term?(%{type: :relation, mode: :search, id_type: :uuid}, "550e8400-e29b-41d4-a716-446655440000")
      false

      iex> skip_relation_search_term?(%{type: :relation, mode: :search, id_type: :integer}, "123")
      false

      iex> skip_relation_search_term?(%{type: :text}, "any value")
      false
  """
  @spec skip_relation_search_term?(map(), term()) :: boolean()
  def skip_relation_search_term?(%{type: :relation, mode: mode, id_type: id_type}, value)
      when mode in [:search, :search_multi] and is_binary(value) do
    not valid_relation_value?(value, id_type)
  end

  def skip_relation_search_term?(%{type: :relation, mode: mode}, value)
      when mode in [:search, :search_multi] and is_binary(value) do
    not valid_relation_value?(value, :uuid)
  end

  def skip_relation_search_term?(_, _), do: false

  @doc """
  Checks if a value is a valid relation filter value for the given ID type.

  ## ID Types

  - `:uuid` / `:uuid_v7` - Must be a valid UUID string
  - `:integer` - Must be a valid integer string
  - `:string` - Any non-empty string is valid

  ## Special Values

  - `"__nil__"` - Always valid, indicates "no selection" or "null"

  ## Examples

      iex> valid_relation_value?("__nil__", :uuid)
      true

      iex> valid_relation_value?("550e8400-e29b-41d4-a716-446655440000", :uuid)
      true

      iex> valid_relation_value?("123", :integer)
      true

      iex> valid_relation_value?("search text", :uuid)
      false

      iex> valid_relation_value?("any-string", :string)
      true
  """
  @spec valid_relation_value?(term(), atom() | nil) :: boolean()
  def valid_relation_value?("__nil__", _id_type), do: true

  def valid_relation_value?(value, id_type)
      when id_type in [:uuid, :uuid_v7] and is_binary(value) do
    match?({:ok, _}, Ash.Type.UUID.cast_input(value, []))
  end

  def valid_relation_value?(value, :integer) when is_binary(value) do
    match?({:ok, _}, Ash.Type.Integer.cast_input(value, []))
  end

  def valid_relation_value?(value, :string) when is_binary(value) and value != "" do
    match?({:ok, _}, Ash.Type.String.cast_input(value, []))
  end

  def valid_relation_value?(_, _), do: false

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.RelationFilterHandler

      alias MishkaGervaz.Table.Web.{State, DataLoader}
      alias MishkaGervaz.Table.Web.DataLoader.RelationLoader
      alias MishkaGervaz.Resource.Info.Table, as: Info

      @impl true
      def handle(action, params, state, socket) do
        do_handle(action, params, state, socket)
      end

      defp do_handle("search", params, state, socket) do
        with {:ok, filter_atom, filter} <- get_filter(params, state),
             {:ok, search_term} <- get_search_term(params, state, filter_atom),
             :ok <- validate_min_chars(search_term, params) do
          filter_map = to_filter_map(filter)

          case relation_loader(state).search_options(filter_map, state, search_term) do
            {:ok, result} ->
              socket =
                update_relation_state(socket, state, filter_atom, result, keep_selected: true)

              {:noreply, socket}

            {:error, _reason} ->
              {:noreply, socket}
          end
        else
          _ ->
            {:noreply, socket}
        end
      end

      defp do_handle("load_more", params, state, socket) do
        with {:ok, filter_atom, filter} <- get_filter(params, state) do
          current_opts = get_current_filter_opts(state, filter_atom)
          current_page = Map.get(current_opts, :page, 1)
          filter_map = to_filter_map(filter)

          case relation_loader(state).load_more_options(filter_map, state, page: current_page + 1) do
            {:ok, result} ->
              merged_options = Map.get(current_opts, :options, []) ++ result.options

              socket =
                update_relation_state(
                  socket,
                  state,
                  filter_atom,
                  %{result | options: merged_options},
                  keep_selected: true
                )

              {:noreply, socket}

            {:error, _reason} ->
              {:noreply, socket}
          end
        else
          _ -> {:noreply, socket}
        end
      end

      defp do_handle("focus", params, state, socket) do
        with {:ok, filter_atom, filter} <- get_filter(params, state) do
          filter_map = to_filter_map(filter)
          selected_options = resolve_selected_options(filter_map, state, filter_atom)

          case relation_loader(state).load_options(filter_map, state, page: 1) do
            {:ok, result} ->
              socket =
                update_relation_state(socket, state, filter_atom, result,
                  selected_options: selected_options,
                  dropdown_open?: true
                )

              {:noreply, socket}

            {:error, _reason} ->
              {:noreply, socket}
          end
        else
          _ -> {:noreply, socket}
        end
      end

      defp do_handle("close_dropdown", params, state, socket) do
        with {:ok, filter_atom, _filter} <- get_filter(params, state) do
          current_opts = get_current_filter_opts(state, filter_atom)
          selected_options = Map.get(current_opts, :selected_options, [])

          new_relation_filter_state =
            Map.put(state.relation_filter_state, filter_atom, %{
              options: [],
              has_more?: false,
              page: 1,
              selected_options: selected_options,
              dropdown_open?: false
            })

          new_state = %{state | relation_filter_state: new_relation_filter_state}
          socket = Phoenix.Component.assign(socket, :table_state, new_state)
          {:noreply, socket}
        else
          _ -> {:noreply, socket}
        end
      end

      defp do_handle("select", params, state, socket) do
        with {:ok, filter_atom, _filter} <- get_filter(params, state) do
          value = sanitize(state, params["id"] || params["value"])
          label = sanitize(state, params["label"] || "")
          current_value = Map.get(state.filter_values, filter_atom)

          {new_filter_values, new_selected_options} =
            if to_string(current_value) == to_string(value) do
              {Map.delete(state.filter_values, filter_atom), []}
            else
              {Map.put(state.filter_values, filter_atom, value), [{label, value}]}
            end

          new_relation_filter_state =
            Map.put(state.relation_filter_state, filter_atom, %{
              options: [],
              has_more?: false,
              page: 1,
              selected_options: new_selected_options,
              dropdown_open?: false
            })

          {new_filter_values, cleaned_relation_state} =
            MishkaGervaz.Helpers.invalidate_dependents(
              new_filter_values,
              state.filter_values,
              state
            )

          new_relation_filter_state =
            Map.merge(cleaned_relation_state, new_relation_filter_state)

          new_state = %{
            state
            | filter_values: new_filter_values,
              relation_filter_state: new_relation_filter_state
          }

          socket = Phoenix.Component.assign(socket, :table_state, new_state)
          socket = DataLoader.load_async(socket, new_state, page: 1, reset: true)
          {:noreply, socket}
        else
          _ -> {:noreply, socket}
        end
      end

      defp do_handle("clear", params, state, socket) do
        with {:ok, filter_atom, _filter} <- get_filter(params, state) do
          new_filter_values = Map.delete(state.filter_values, filter_atom)

          new_relation_filter_state =
            Map.put(state.relation_filter_state, filter_atom, %{
              options: [],
              has_more?: false,
              page: 1,
              selected_options: [],
              dropdown_open?: false
            })

          {new_filter_values, cleaned_relation_state} =
            MishkaGervaz.Helpers.invalidate_dependents(
              new_filter_values,
              state.filter_values,
              state
            )

          new_relation_filter_state =
            Map.merge(cleaned_relation_state, new_relation_filter_state)

          new_state = %{
            state
            | filter_values: new_filter_values,
              relation_filter_state: new_relation_filter_state
          }

          socket = Phoenix.Component.assign(socket, :table_state, new_state)
          socket = DataLoader.load_async(socket, new_state, page: 1, reset: true)
          {:noreply, socket}
        else
          _ -> {:noreply, socket}
        end
      end

      defp do_handle("toggle", params, state, socket) do
        with {:ok, filter_atom, _filter} <- get_filter(params, state),
             {:ok, value, label} <- get_toggle_params(params, state) do
          current_list = get_current_selected_list(state, filter_atom)
          is_selected = value in current_list

          new_list = toggle_value(current_list, value, is_selected)

          new_selected_options =
            toggle_selected_option(state, filter_atom, value, label, is_selected)

          {new_filter_values, new_relation_filter_state} =
            build_toggle_state(state, filter_atom, new_list, new_selected_options)

          {new_filter_values, cleaned_relation_state} =
            MishkaGervaz.Helpers.invalidate_dependents(
              new_filter_values,
              state.filter_values,
              state
            )

          new_relation_filter_state =
            Map.merge(cleaned_relation_state, new_relation_filter_state)

          new_state = %{
            state
            | relation_filter_state: new_relation_filter_state,
              filter_values: new_filter_values
          }

          socket = Phoenix.Component.assign(socket, :table_state, new_state)
          socket = DataLoader.load_async(socket, new_state, page: 1, reset: true)
          {:noreply, socket}
        else
          _ -> {:noreply, socket}
        end
      end

      defp do_handle(_action, _params, _state, socket) do
        {:noreply, socket}
      end

      defp get_filter(params, state) do
        filter_name = sanitize(state, params["filter"])
        filter_atom = String.to_existing_atom(filter_name)
        filter = Enum.find(state.static.filters, &(&1.name == filter_atom))

        if filter do
          {:ok, filter_atom, filter}
        else
          {:error, :filter_not_found}
        end
      rescue
        ArgumentError -> {:error, :invalid_filter_name}
      end

      defp get_search_term(params, state, filter_atom) do
        search_key = "_search_#{filter_atom}"
        search_term = sanitize(state, params[search_key] || params["value"] || "")
        {:ok, search_term}
      end

      defp validate_min_chars(search_term, params) do
        min_chars = String.to_integer(params["min-chars"] || "1")

        if String.length(search_term) >= min_chars do
          :ok
        else
          {:error, :below_min_chars}
        end
      end

      defp get_toggle_params(params, state) do
        value = sanitize(state, params["id"]) |> to_string()
        label = sanitize(state, params["label"] || "")
        {:ok, value, label}
      end

      defp get_current_filter_opts(state, filter_atom) do
        Map.get(state.relation_filter_state, filter_atom, %{})
      end

      defp get_current_selected_list(state, filter_atom) do
        raw_values = Map.get(state.filter_values, filter_atom)

        case raw_values do
          nil -> []
          "" -> []
          [] -> []
          list when is_list(list) -> Enum.map(list, &to_string/1) |> Enum.reject(&(&1 == ""))
          single -> [to_string(single)]
        end
      end

      defp to_filter_map(filter) when is_struct(filter), do: Map.from_struct(filter)
      defp to_filter_map(filter) when is_map(filter), do: filter

      defp resolve_selected_options(filter_map, state, filter_atom) do
        current_opts = get_current_filter_opts(state, filter_atom)
        current_selected_options = Map.get(current_opts, :selected_options, [])
        selected_list = get_current_selected_list(state, filter_atom)

        if selected_list != [] and current_selected_options == [] do
          case relation_loader(state).resolve_selected(filter_map, state, selected_list) do
            {:ok, resolved} -> resolved
            {:error, _} -> current_selected_options
          end
        else
          current_selected_options
        end
      end

      defp toggle_value(current_list, value, true = _is_selected) do
        Enum.reject(current_list, &(&1 == value))
      end

      defp toggle_value(current_list, value, false = _is_selected) do
        current_list ++ [value]
      end

      defp toggle_selected_option(state, filter_atom, value, label, is_selected) do
        current_opts = get_current_filter_opts(state, filter_atom)
        current_selected = Map.get(current_opts, :selected_options, [])

        if is_selected do
          Enum.reject(current_selected, fn {_, v} -> to_string(v) == value end)
        else
          current_selected ++ [{label, value}]
        end
      end

      defp build_toggle_state(state, filter_atom, new_list, new_selected_options) do
        current_opts = get_current_filter_opts(state, filter_atom)

        base_opts = %{
          options: Map.get(current_opts, :options, []),
          has_more?: Map.get(current_opts, :has_more?, false),
          page: Map.get(current_opts, :page, 1),
          dropdown_open?: true
        }

        if new_list == [] do
          {
            Map.delete(state.filter_values, filter_atom),
            Map.put(
              state.relation_filter_state,
              filter_atom,
              Map.put(base_opts, :selected_options, [])
            )
          }
        else
          {
            Map.put(state.filter_values, filter_atom, new_list),
            Map.put(
              state.relation_filter_state,
              filter_atom,
              Map.put(base_opts, :selected_options, new_selected_options)
            )
          }
        end
      end

      defp update_relation_state(socket, state, filter_atom, result, opts \\ []) do
        current_opts = get_current_filter_opts(state, filter_atom)

        selected_options =
          if Keyword.get(opts, :keep_selected, false) do
            Map.get(current_opts, :selected_options, [])
          else
            Keyword.get(opts, :selected_options, [])
          end

        dropdown_open? = Keyword.get(opts, :dropdown_open?, true)

        new_relation_filter_state =
          Map.put(state.relation_filter_state, filter_atom, %{
            options: result.options,
            has_more?: result.has_more?,
            page: result.page,
            selected_options: selected_options,
            dropdown_open?: dropdown_open?
          })

        new_state = %{state | relation_filter_state: new_relation_filter_state}
        Phoenix.Component.assign(socket, :table_state, new_state)
      end

      defp sanitize(_state, value) do
        MishkaGervaz.Table.Web.Events.SanitizationHandler.Default.sanitize(value)
      end

      @spec relation_loader(State.t()) :: module()
      defp relation_loader(state) do
        resource = state.static.resource
        dsl_config = Info.data_loader(resource)
        Map.get(dsl_config || %{}, :relation, RelationLoader.Default)
      end

      defoverridable handle: 4
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.RelationFilterHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.RelationFilterHandler
end

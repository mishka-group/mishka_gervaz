defmodule MishkaGervaz.Form.Web.Events.RelationHandler do
  @moduledoc """
  Handles relation field events for search, multi-select, and dropdown state.

  Follows the same pattern as `MishkaGervaz.Table.Web.Events.RelationFilterHandler`.

  ## Events Handled

  - `search` - Search options by term (debounced)
  - `focus` - Open dropdown and load initial options
  - `close_dropdown` - Close dropdown on click-away
  - `select` - Single select (for :search mode)
  - `toggle` - Toggle selection (for :search_multi mode)
  - `clear` - Clear all selections
  - `load_more` - Load next page of options

  ## Customization

      defmodule MyApp.Form.RelationHandler do
        use MishkaGervaz.Form.Web.Events.RelationHandler

        def handle("toggle", params, state, socket) do
          super("toggle", params, state, socket)
        end
      end

  Top-level helpers (`get_field/2`, `get_search_term/2`,
  `validate_min_chars/2`, `resolve_selected_options/3`, `revalidate_form/3`,
  `update_relation_state/5`, `reload_dependent_fields/3`, etc.) are public
  so user overrides can reuse them — they live outside the `__using__`
  macro to avoid per-consumer compile cost.

  See `MishkaGervaz.Form.Web.Events`,
  `MishkaGervaz.Form.Web.DataLoader.RelationLoader`, and the sibling
  sub-handlers.
  """

  alias MishkaGervaz.Form.Web.{State, DataLoader}

  @type state :: State.t()
  @type socket :: Phoenix.LiveView.Socket.t()
  @type params :: map()

  @callback handle(action :: String.t(), params :: params(), state :: state(), socket :: socket()) ::
              {:noreply, socket()}

  @doc false
  def do_handle("search", params, state, socket) do
    with {:ok, field_atom, field} <- get_field(params, state),
         {:ok, search_term} <- get_search_term(params, field_atom) do
      if validate_min_chars(search_term, params) == :ok do
        relation_mod = DataLoader.Default.relation_loader()

        case relation_mod.search_options(field, state, search_term) do
          {:ok, options, has_more?} ->
            socket =
              update_relation_state(
                socket,
                state,
                field_atom,
                %{
                  options: options,
                  has_more?: has_more?,
                  page: 1
                },
                keep_selected: true,
                dropdown_open?: true,
                search_term: search_term
              )

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end
      else
        selected_options = resolve_selected_options(field, state, field_atom)
        relation_mod = DataLoader.Default.relation_loader()

        case relation_mod.load_options(field, state) do
          {:ok, options, has_more?} ->
            merged = prepend_selected(selected_options, options)

            socket =
              update_relation_state(
                socket,
                state,
                field_atom,
                %{
                  options: merged,
                  has_more?: has_more?,
                  page: 1
                },
                selected_options: selected_options,
                dropdown_open?: true,
                search_term: nil
              )

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle("focus", params, state, socket) do
    with {:ok, field_atom, field} <- get_field(params, state) do
      selected_options = resolve_selected_options(field, state, field_atom)
      relation_mod = DataLoader.Default.relation_loader()

      case relation_mod.load_options(field, state) do
        {:ok, options, has_more?} ->
          merged = prepend_selected(selected_options, options)

          socket =
            update_relation_state(
              socket,
              state,
              field_atom,
              %{
                options: merged,
                has_more?: has_more?,
                page: 1
              },
              selected_options: selected_options,
              dropdown_open?: true,
              search_term: nil
            )

          {:noreply, socket}

        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle("close_dropdown", params, state, socket) do
    with {:ok, field_atom, _field} <- get_field(params, state) do
      current_opts = get_current_opts(state, field_atom)
      selected_options = Map.get(current_opts, :selected_options, [])

      relation_options =
        Map.put(state.relation_options, field_atom, %{
          options: [],
          has_more?: false,
          page: 1,
          selected_options: selected_options,
          dropdown_open?: false
        })

      state = State.update(state, relation_options: relation_options)
      socket = Phoenix.Component.assign(socket, :form_state, state)
      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle("select", params, state, socket) do
    with {:ok, field_atom, _field} <- get_field(params, state) do
      value = params["id"] || params["value"] || ""
      label = params["label"] || ""
      current_value = Map.get(state.field_values, field_atom)

      {new_field_values, new_selected_options, form_value} =
        if to_string(current_value) == to_string(value) do
          {Map.delete(state.field_values, field_atom), [], nil}
        else
          {Map.put(state.field_values, field_atom, value), [{label, value}], value}
        end

      relation_options =
        Map.put(state.relation_options, field_atom, %{
          options: [],
          has_more?: false,
          page: 1,
          selected_options: new_selected_options,
          dropdown_open?: false
        })

      state =
        State.update(state,
          field_values: new_field_values,
          relation_options: relation_options,
          dirty?: true
        )

      state = revalidate_form(state, field_atom, form_value)
      socket = Phoenix.Component.assign(socket, :form_state, state)
      socket = reload_dependent_fields(socket, state, field_atom)

      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle("toggle", params, state, socket) do
    with {:ok, field_atom, _field} <- get_field(params, state),
         {:ok, value, label} <- get_toggle_params(params) do
      current_list = get_current_selected_list(state, field_atom)
      is_selected = value in current_list

      new_list = toggle_value(current_list, value, is_selected)

      new_selected_options =
        toggle_selected_option(state, field_atom, value, label, is_selected)

      current_opts = get_current_opts(state, field_atom)

      relation_options =
        Map.put(state.relation_options, field_atom, %{
          options: Map.get(current_opts, :options, []),
          has_more?: Map.get(current_opts, :has_more?, false),
          page: Map.get(current_opts, :page, 1),
          selected_options: new_selected_options,
          dropdown_open?: true
        })

      new_field_values =
        if new_list == [],
          do: Map.delete(state.field_values, field_atom),
          else: Map.put(state.field_values, field_atom, new_list)

      state =
        State.update(state,
          field_values: new_field_values,
          relation_options: relation_options,
          dirty?: true
        )

      state = revalidate_form(state, field_atom, new_list)
      socket = Phoenix.Component.assign(socket, :form_state, state)
      socket = reload_dependent_fields(socket, state, field_atom)
      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle("clear", params, state, socket) do
    with {:ok, field_atom, _field} <- get_field(params, state) do
      relation_options =
        Map.put(state.relation_options, field_atom, %{
          options: [],
          has_more?: false,
          page: 1,
          selected_options: [],
          dropdown_open?: false
        })

      state =
        state
        |> State.update(
          field_values: Map.delete(state.field_values, field_atom),
          relation_options: relation_options,
          dirty?: true
        )
        |> revalidate_form(field_atom, nil)

      socket = Phoenix.Component.assign(socket, :form_state, state)
      socket = reload_dependent_fields(socket, state, field_atom)
      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle("load_more", params, state, socket) do
    with {:ok, field_atom, field} <- get_field(params, state) do
      current_opts = get_current_opts(state, field_atom)
      current_page = Map.get(current_opts, :page, 1)
      search_term = Map.get(current_opts, :search_term)
      relation_mod = DataLoader.Default.relation_loader()

      result =
        if search_term do
          relation_mod.search_options(field, state, search_term, page: current_page + 1)
        else
          relation_mod.load_options(field, state, page: current_page + 1)
        end

      case result do
        {:ok, options, has_more?} ->
          selected_options = Map.get(current_opts, :selected_options, [])
          filtered_new = reject_selected(selected_options, options)
          merged = Map.get(current_opts, :options, []) ++ filtered_new

          socket =
            update_relation_state(
              socket,
              state,
              field_atom,
              %{
                options: merged,
                has_more?: has_more?,
                page: current_page + 1
              },
              keep_selected: true,
              dropdown_open?: true,
              search_term: search_term
            )

          {:noreply, socket}

        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def do_handle(_action, _params, _state, socket) do
    {:noreply, socket}
  end

  @doc false
  def get_field(params, state) do
    field_name = params["filter"] || params["field"]
    field_atom = String.to_existing_atom(field_name)
    field = Enum.find(state.static.fields, &(&1.name == field_atom))

    if field do
      {:ok, field_atom, field}
    else
      {:error, :field_not_found}
    end
  rescue
    ArgumentError -> {:error, :invalid_field_name}
  end

  @doc false
  def get_search_term(params, field_atom) do
    search_key = "_search_#{field_atom}"
    search_term = params[search_key] || params["value"] || ""
    {:ok, search_term}
  end

  @doc false
  def validate_min_chars(search_term, params) do
    min_chars = String.to_integer(params["min-chars"] || "1")

    if String.length(search_term) >= min_chars do
      :ok
    else
      {:error, :below_min_chars}
    end
  end

  @doc false
  def get_toggle_params(params) do
    value = to_string(params["id"] || "")
    label = params["label"] || ""
    {:ok, value, label}
  end

  @doc false
  def get_current_opts(state, field_atom) do
    Map.get(state.relation_options, field_atom, %{})
  end

  @doc false
  def get_current_selected_list(state, field_atom) do
    case Map.get(state.field_values, field_atom) do
      nil -> []
      "" -> []
      [] -> []
      list when is_list(list) -> Enum.map(list, &to_string/1) |> Enum.reject(&(&1 == ""))
      single -> [to_string(single)]
    end
  end

  @doc false
  def resolve_selected_options(field, state, field_atom) do
    current_opts = get_current_opts(state, field_atom)
    current_selected = Map.get(current_opts, :selected_options, [])
    selected_list = get_current_selected_list(state, field_atom)

    if selected_list != [] and current_selected == [] do
      relation_mod = DataLoader.Default.relation_loader()

      case relation_mod.resolve_selected(field, state, selected_list) do
        {:ok, resolved} -> resolved
        {:error, _} -> current_selected
      end
    else
      current_selected
    end
  end

  @doc false
  def prepend_selected([], options), do: options
  def prepend_selected(selected, options), do: selected ++ reject_selected(selected, options)

  @doc false
  def reject_selected([], options), do: options

  def reject_selected(selected, options) do
    selected_values = MapSet.new(selected, fn {_, v} -> to_string(v) end)
    selected? = fn {_, v} -> MapSet.member?(selected_values, to_string(v)) end

    Enum.flat_map(options, fn
      {group_label, opts} when is_list(opts) ->
        case Enum.reject(opts, selected?) do
          [] -> []
          rest -> [{group_label, rest}]
        end

      option ->
        if selected?.(option), do: [], else: [option]
    end)
  end

  @doc false
  def toggle_value(current_list, value, true), do: Enum.reject(current_list, &(&1 == value))
  def toggle_value(current_list, value, false), do: current_list ++ [value]

  @doc false
  def toggle_selected_option(state, field_atom, value, label, is_selected) do
    current_opts = get_current_opts(state, field_atom)
    current_selected = Map.get(current_opts, :selected_options, [])

    if is_selected do
      Enum.reject(current_selected, fn {_, v} -> to_string(v) == value end)
    else
      current_selected ++ [{label, value}]
    end
  end

  @doc false
  def revalidate_form(state, field_atom, value),
    do: revalidate_form(state, %{field_atom => value})

  @doc false
  def revalidate_form(state, values) when is_map(values) do
    case state.form do
      nil ->
        state

      form ->
        form_params =
          Enum.reduce(values, AshPhoenix.Form.params(form.source), fn {field_atom, value}, acc ->
            Map.put(acc, to_string(field_atom), if(value == "__nil__", do: nil, else: value))
          end)

        validated =
          form.source
          |> AshPhoenix.Form.validate(form_params)
          |> Phoenix.Component.to_form()

        show_errors? = form.source.submitted_once? or form.source.type != :create

        errors =
          if show_errors? do
            MishkaGervaz.Form.Web.Events.SubmitHandler.format_form_errors(validated)
          else
            %{}
          end

        State.update(state, form: validated, errors: errors)
    end
  end

  @doc false
  def update_relation_state(socket, state, field_atom, result, opts \\ []) do
    current_opts = get_current_opts(state, field_atom)

    selected_options =
      if Keyword.get(opts, :keep_selected, false) do
        Map.get(current_opts, :selected_options, [])
      else
        Keyword.get(opts, :selected_options, [])
      end

    dropdown_open? = Keyword.get(opts, :dropdown_open?, true)

    search_term =
      if Keyword.has_key?(opts, :search_term) do
        Keyword.get(opts, :search_term)
      else
        Map.get(current_opts, :search_term)
      end

    relation_options =
      Map.put(state.relation_options, field_atom, %{
        options: result.options,
        has_more?: result.has_more?,
        page: result.page,
        selected_options: selected_options,
        dropdown_open?: dropdown_open?,
        search_term: search_term
      })

    state = State.update(state, relation_options: relation_options)
    Phoenix.Component.assign(socket, :form_state, state)
  end

  @doc """
  Empties every field that depends on `changed_field_atom`, directly or down the chain, and loads
  the options each one can offer now.

  Each dependent loses its value in `state.field_values` and is set to `nil` in the form's params,
  so a value picked under the old parent is never saved. A dependent is loaded again when its own
  parent still has a value, or when its options come from the state.
  """
  @spec reload_dependent_fields(socket(), state(), atom()) :: socket()
  def reload_dependent_fields(socket, state, changed_field_atom) do
    fields = state.static.fields

    dependents =
      MishkaGervaz.Helpers.find_all_dependents(MapSet.new([changed_field_atom]), fields)

    case MapSet.to_list(dependents) do
      [] ->
        socket

      names ->
        cleared = State.update(state, field_values: Map.drop(state.field_values, names))

        to_load =
          Enum.filter(fields, fn field ->
            MapSet.member?(dependents, field.name) and
              DataLoader.Helpers.loadable_dependent?(field, cleared)
          end)

        load_names = MapSet.new(to_load, & &1.name)

        relation_options =
          Enum.reduce(names, state.relation_options, fn name, acc ->
            Map.put(acc, name, %{
              options: [],
              has_more?: false,
              loading?: MapSet.member?(load_names, name),
              page: 1,
              selected_options: [],
              dropdown_open?: false
            })
          end)

        state =
          cleared
          |> State.update(relation_options: relation_options)
          |> revalidate_form(Map.new(names, &{&1, nil}))

        socket = Phoenix.Component.assign(socket, :form_state, state)

        Enum.reduce(to_load, socket, fn field, acc ->
          DataLoader.load_relation_options(acc, state, field.name)
        end)
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Form.Web.Events.RelationHandler

      @impl true
      def handle(action, params, state, socket) do
        MishkaGervaz.Form.Web.Events.RelationHandler.do_handle(action, params, state, socket)
      end

      defoverridable handle: 4
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.RelationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.RelationHandler
end

defmodule MishkaGervaz.Form.Types.Field.Relation do
  @moduledoc """
  Relation field type for selecting related records in forms.

  Follows the same pattern as `MishkaGervaz.Table.Types.Filter.Relation`.

  ## Modes
  - `:static` - Load all options at once (default, for small datasets)
  - `:load_more` - Paginated with "Load more" button
  - `:search` - Searchable single select
  - `:search_multi` - Searchable multi select

  ## Examples

      field :site_id, :relation do
        mode :static
        display_field :name
      end

      field :category_id, :relation do
        mode :search_multi
        search_field :name
        min_chars 1
      end
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :relation}

  @doc """
  Renders the relation field input by building assigns and calling the UI adapter.

  Delegates to the appropriate UI adapter function based on mode:
  - `:static` → `ui.select/1`
  - `:search` → `ui.search_select/1`
  - `:load_more` → `ui.load_more_select/1`
  - `:search_multi` → `ui.multi_select/1`
  """
  @spec render_input(map(), map(), map(), module()) :: Phoenix.LiveView.Rendered.t()
  def render_input(field, rel_data, state_assigns, ui) do
    mode = Map.get(field, :mode, :static)
    assigns = build_assigns(field, rel_data, state_assigns, mode)

    case mode do
      :static -> ui.select(assigns)
      :search -> ui.search_select(assigns)
      :load_more -> ui.load_more_select(assigns)
      :search_multi -> ui.multi_select(assigns)
      _ -> ui.select(assigns)
    end
  end

  defp build_assigns(field, rel_data, state_assigns, mode) do
    option_list = Map.get(rel_data, :options, [])

    base = %{
      name: field.name,
      filter_name: field.name,
      field: state_assigns[:form_field],
      id: "form-#{field.name}",
      options: option_list,
      placeholder: get_ui(field, :placeholder, "Select..."),
      icon: get_ui(field, :icon),
      has_more?: Map.get(rel_data, :has_more?, false),
      loading?: Map.get(rel_data, :loading?, false),
      dropdown_open?: Map.get(rel_data, :dropdown_open?, false),
      disabled: Map.get(field, :disabled, false),
      myself: state_assigns[:myself]
    }

    merged =
      case mode do
        :search_multi ->
          Map.merge(base, %{
            selected: normalize_selected(state_assigns[:field_values], field.name),
            selected_options: Map.get(rel_data, :selected_options, []),
            min_chars: Map.get(field, :min_chars, 1),
            debounce: get_ui(field, :debounce, 300),
            search_term: Map.get(rel_data, :search_term)
          })

        m when m in [:search, :load_more] ->
          Map.merge(base, %{
            value: Map.get(state_assigns[:field_values] || %{}, field.name, ""),
            selected_options: Map.get(rel_data, :selected_options, []),
            min_chars: Map.get(field, :min_chars, 1),
            debounce: get_ui(field, :debounce, 300),
            search_term: Map.get(rel_data, :search_term)
          })

        _ ->
          Map.merge(base, %{
            value: state_assigns[:current_value] || ""
          })
      end

    Map.put(merged, :__changed__, Map.new(Map.keys(merged), &{&1, true}))
  end

  defp normalize_selected(field_values, field_name) do
    case Map.get(field_values || %{}, field_name) do
      nil -> []
      "" -> []
      values when is_list(values) -> Enum.reject(values, &(is_nil(&1) or &1 == ""))
      value -> [value]
    end
  end

  defp get_ui(field, key, default \\ nil) do
    case Map.get(field, :ui) do
      ui when is_map(ui) -> Map.get(ui, key, default)
      _ -> default
    end
  end
end

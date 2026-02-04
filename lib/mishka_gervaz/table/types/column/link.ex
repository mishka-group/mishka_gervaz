defmodule MishkaGervaz.Table.Types.Column.Link do
  @moduledoc """
  Link column type.

  Renders values as clickable links.

  ## Options (via column.ui.extra)

  - `:path_fn` - Function to generate path from record (required for navigation)
    Example: `fn record -> "/users/\#{record.id}" end`
  - `:external` - Open in new tab (default: false)
  - `:class` - CSS class for link (default: "text-blue-600 hover:text-blue-800")
  - `:label_fn` - Function to generate label (default: uses column value)
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  def render(value, column, record, ui) do
    extra = get_extra(column)

    label =
      case extra[:label_fn] do
        func when is_function(func, 1) -> func.(record)
        _ -> to_string(value)
      end

    path =
      case extra[:path_fn] do
        func when is_function(func, 1) -> func.(record)
        nil -> "#"
      end

    external = extra[:external] || false

    if external do
      render_external_link(label, path, extra[:class], ui)
    else
      ui.nav_link(%{
        __changed__: %{},
        navigate: path,
        label: label,
        class: extra[:class],
        variant: :default
      })
    end
  end

  @spec render_external_link(String.t(), String.t(), String.t() | nil, module()) ::
          Phoenix.LiveView.Rendered.t()
  defp render_external_link(label, path, class, ui) do
    ui.nav_link(%{
      __changed__: %{},
      navigate: path,
      label: label,
      class: class,
      variant: :external,
      external: true
    })
  end

  @spec get_extra(map()) :: map()
  defp get_extra(%{ui: %{extra: extra}}) when is_map(extra), do: extra
  defp get_extra(_), do: %{}
end

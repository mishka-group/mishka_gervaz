defmodule MishkaGervaz.Table.Types.Action.Link do
  @moduledoc """
  Link action type - renders a navigation link.

  Used for actions like :show_link, :edit_link that navigate to another page.

  ## Route Building

  An action named `:show`, `:show_link`, `:edit` or `:edit_link` with no `path` builds its address
  from the table's `identity` route, its `:param` segments filled in from `state.path_params`:
  - `:show` / `:show_link` → `{route}/{id}`
  - `:edit` / `:edit_link` → `{route}/{id}/edit`

  A table with no route links to `"#"`. A `path` function always wins over the built address:

      action :view, type: :link, path: fn record -> "/custom/\#{record.id}" end

  See `MishkaGervaz.Table.Types.Action` (registry),
  `MishkaGervaz.Table.Behaviours.ActionType`,
  `MishkaGervaz.Table.Entities.RowAction`, and
  `MishkaGervaz.Table.Entities.BulkAction`.

  `MishkaGervaz.Table.Behaviours.ActionType` documents what may go in the assigns map.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [action_label: 1, dynamic_component: 1, maybe_assign: 3]

  @impl true
  def render(assigns, action, record, ui, _target) do
    path = build_path(assigns, action, record)

    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :nav_link)
      |> assign(:variant, action_variant(action[:name]))
      |> assign(:navigate, path)
      |> assign(:label, action_label(action))
      |> maybe_assign(:icon, action[:ui][:icon])
      |> maybe_assign(:class, action[:ui][:class])

    ~H"""
    <.dynamic_component {assigns} />
    """
  end

  @spec action_variant(atom()) :: atom()
  defp action_variant(:edit), do: :edit
  defp action_variant(:edit_link), do: :edit
  defp action_variant(:show), do: :show
  defp action_variant(:show_link), do: :show
  defp action_variant(_), do: :default

  @spec build_path(map(), map(), struct()) :: String.t()
  defp build_path(_assigns, %{path: path}, record) when is_function(path, 1), do: path.(record)
  defp build_path(_assigns, %{path: path}, _record) when is_binary(path), do: path

  defp build_path(assigns, %{name: name}, record) when name in [:show, :show_link],
    do: build_route(assigns, record, :show)

  defp build_path(assigns, %{name: name}, record) when name in [:edit, :edit_link],
    do: build_route(assigns, record, :edit)

  defp build_path(_assigns, _action, _record), do: "#"

  @spec build_route(map(), struct(), :show | :edit) :: String.t()
  defp build_route(assigns, record, type) do
    case get_route_pattern(assigns) do
      route when is_binary(route) and route != "" ->
        base =
          route
          |> substitute_path_params(get_path_params(assigns))
          |> String.trim_trailing("/")

        record_route(base, record, type)

      _ ->
        "#"
    end
  end

  @spec record_route(String.t(), struct(), :show | :edit) :: String.t()
  defp record_route(base, record, :show), do: "#{base}/#{record.id}"
  defp record_route(base, record, :edit), do: "#{base}/#{record.id}/edit"

  @spec substitute_path_params(String.t(), map()) :: String.t()
  defp substitute_path_params(route, params) when map_size(params) == 0, do: route

  defp substitute_path_params(route, params) do
    Enum.reduce(params, route, fn {name, value}, acc ->
      String.replace(acc, ":#{name}", to_string(value))
    end)
  end

  @spec get_route_pattern(map()) :: String.t() | nil
  defp get_route_pattern(%{state: %{static: %{config: config}}}), do: config_route(config)
  defp get_route_pattern(%{static: %{config: config}}), do: config_route(config)
  defp get_route_pattern(%{state: %{config: config}}), do: config_route(config)
  defp get_route_pattern(_assigns), do: nil

  @spec config_route(map() | nil) :: String.t() | nil
  defp config_route(%{identity: %{route: route}}), do: route
  defp config_route(_config), do: nil

  @spec get_path_params(map()) :: map()
  defp get_path_params(assigns) do
    cond do
      is_map(assigns[:path_params]) and assigns[:path_params] != %{} ->
        assigns[:path_params]

      is_map(assigns[:state]) and is_map(Map.get(assigns[:state], :path_params)) ->
        Map.get(assigns[:state], :path_params)

      true ->
        %{}
    end
  end
end

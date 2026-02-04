defmodule MishkaGervaz.Table.Types.Action.Link do
  @moduledoc """
  Link action type - renders a navigation link.

  Used for actions like :show_link, :edit_link that navigate to another page.

  ## Route Building

  Routes are built from `state.static.config[:identity][:route]`:
  - `:show` / `:show_link` → `{route}/{id}`
  - `:edit` / `:edit_link` → `{route}/{id}/edit`

  Or use a custom path function:

      action :view, type: :link, path: fn record -> "/custom/\#{record.id}" end
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [humanize: 1, dynamic_component: 1, maybe_assign: 3, resolve_label: 1]

  @impl true
  def render(assigns, action, record, ui, _target) do
    path = build_path(assigns, action, record)

    assigns =
      %{__changed__: %{}}
      |> assign(:module, ui)
      |> assign(:function, :nav_link)
      |> assign(:variant, action_variant(action[:name]))
      |> assign(:navigate, path)
      |> assign(:label, resolve_label(action[:ui][:label]) || humanize(action[:name]))
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
  defp build_path(assigns, action, record) do
    cond do
      is_function(action[:path], 1) ->
        action[:path].(record)

      action[:name] in [:show_link, :show] ->
        build_route(assigns, record, :show)

      action[:name] in [:edit_link, :edit] ->
        build_route(assigns, record, :edit)

      true ->
        action[:path] || "#"
    end
  end

  @spec build_route(map(), struct(), :show | :edit) :: String.t()
  defp build_route(assigns, record, type) do
    base =
      get_route_pattern(assigns)
      |> substitute_path_params(get_path_params(assigns))
      |> String.trim_trailing("/")

    case type do
      :show -> "#{base}/#{record.id}"
      :edit -> "#{base}/#{record.id}/edit"
    end
  end

  @spec substitute_path_params(String.t(), map()) :: String.t()
  defp substitute_path_params(route, params) when map_size(params) == 0, do: route

  defp substitute_path_params(route, params) do
    Enum.reduce(params, route, fn {name, value}, acc ->
      String.replace(acc, ":#{name}", to_string(value))
    end)
  end

  @spec get_route_pattern(map()) :: String.t()
  defp get_route_pattern(assigns) do
    cond do
      is_map(assigns[:state]) and is_map(assigns[:state][:static]) ->
        get_in(assigns, [:state, :static, :config, :identity, :route]) || ""

      is_map(assigns[:state]) and is_map(assigns[:state][:config]) ->
        get_in(assigns, [:state, :config, :identity, :route]) || ""

      is_map(assigns[:static]) ->
        get_in(assigns, [:static, :config, :identity, :route]) || ""

      true ->
        ""
    end
  end

  @spec get_path_params(map()) :: map()
  defp get_path_params(assigns) do
    cond do
      is_map(assigns[:path_params]) and assigns[:path_params] != %{} ->
        assigns[:path_params]

      is_map(assigns[:state]) and is_map(Map.get(assigns[:state], :path_params)) ->
        Map.get(assigns[:state], :path_params) || %{}

      true ->
        %{}
    end
  end
end

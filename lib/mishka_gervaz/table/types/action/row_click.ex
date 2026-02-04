defmodule MishkaGervaz.Table.Types.Action.RowClick do
  @moduledoc """
  Row click action type - makes the entire row clickable.

  Unlike button-based actions, row_click applies to the entire table row.
  It can navigate to a path or emit an event when the row is clicked.

  ## Usage

      row_actions do
        action :view, type: :row_click, path: "/posts/{id}"
      end

  Or with a custom event:

      row_actions do
        action :select, type: :row_click, event: :row_selected
      end

  The action is not rendered as a button - instead, it's used by the
  template to make rows clickable.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  @impl true
  def render(_assigns, _action, _record, _ui, _target) do
    assigns = %{}

    ~H"""
    """
  end

  @doc """
  Build the click handler data for a row.

  Returns a map with :navigate or :event that templates can use
  to make the row clickable.
  """
  @spec build_click_handler(map(), struct()) :: map()
  def build_click_handler(action, record) do
    cond do
      action[:path] ->
        path = build_path(action[:path], record)
        %{navigate: path}

      action[:event] ->
        event = action[:event] || action[:name]
        %{event: event, id: record.id}

      true ->
        %{event: action[:name], id: record.id}
    end
  end

  @spec build_path(term(), struct()) :: String.t()
  defp build_path(path, record) when is_function(path, 1), do: path.(record)

  defp build_path(path, record) when is_binary(path) do
    Regex.replace(~r/\{(\w+)\}/, path, fn _, field ->
      record |> Map.get(String.to_existing_atom(field), "") |> to_string()
    end)
  end

  defp build_path(path, _record), do: path
end

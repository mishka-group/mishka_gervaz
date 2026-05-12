defmodule MishkaGervaz.Table.Web.DataLoader.Helpers do
  @moduledoc """
  Pure data helpers for `MishkaGervaz.Table.Web.DataLoader`.

  Extracted from the `__using__` macro so the same primitives are
  reusable in user overrides and directly testable.
  """

  @type sort_entry :: {atom(), :asc | :desc}
  @type mode_state :: %{
          filter_values: map(),
          sort_fields: [sort_entry()],
          selected_ids: MapSet.t(any()),
          excluded_ids: MapSet.t(any()),
          select_all?: boolean()
        }

  @doc """
  Rewrites the order of every entry in `sorts` whose field belongs to
  `db_fields`, leaving the rest untouched.
  """
  @spec toggle_sort_group([sort_entry()], [atom()], :asc | :desc) :: [sort_entry()]
  def toggle_sort_group(sorts, db_fields, new_order) do
    Enum.map(sorts, fn {f, ord} ->
      if f in db_fields, do: {f, new_order}, else: {f, ord}
    end)
  end

  @doc """
  Drops every entry from `sorts` whose field is in `db_fields`.
  """
  @spec remove_sort_group([sort_entry()], [atom()]) :: [sort_entry()]
  def remove_sort_group(sorts, db_fields) do
    Enum.reject(sorts, fn {f, _} -> f in db_fields end)
  end

  @doc """
  The empty starting state for one of the two archive-status modes
  (`:active` or `:archived`). Used by `apply_archive_status/3` to
  swap state when toggling between modes.
  """
  @spec default_mode_state() :: mode_state()
  def default_mode_state do
    %{
      filter_values: %{},
      sort_fields: [],
      selected_ids: MapSet.new(),
      excluded_ids: MapSet.new(),
      select_all?: false
    }
  end
end

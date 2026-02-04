defmodule MishkaGervaz.Table.Web.Events.SelectionHandler do
  @moduledoc """
  Handles selection operations for Events module.

  This module provides functions for managing row selection state,
  including individual selection, select-all, and clear selection.

  ## Customization

  You can create a custom SelectionHandler:

      defmodule MyApp.CustomSelectionHandler do
        use MishkaGervaz.Table.Web.Events.SelectionHandler

        # Custom toggle that limits selection to 10 items
        def toggle_select(state, id) do
          if MapSet.size(state.selected_ids) >= 10 and
             not MapSet.member?(state.selected_ids, id) do
            {:error, :max_selection_reached}
          else
            super(state, id)
          end
        end
      end

  Then configure it in your resource's DSL:

      mishka_gervaz do
        table do
          events do
            selection MyApp.CustomSelectionHandler
          end
        end
      end
  """

  alias MishkaGervaz.Table.Web.State

  @type state :: State.t()

  @doc """
  Toggles selection for a single row.

  When `select_all?` is true, toggles the ID in `excluded_ids`.
  When `select_all?` is false, toggles the ID in `selected_ids`.

  Returns the updated state.
  """
  @callback toggle_select(state :: state(), id :: String.t()) :: state()

  @doc """
  Toggles select-all state.

  Resets both `selected_ids` and `excluded_ids` when toggling.
  Returns the updated state.
  """
  @callback toggle_select_all(state :: state()) :: state()

  @doc """
  Clears all selection state.

  Resets `select_all?`, `selected_ids`, and `excluded_ids`.
  Returns the updated state.
  """
  @callback clear_selection(state :: state()) :: state()

  @doc """
  Returns the effective selected IDs for bulk actions.

  Returns one of:
  - `list()` - List of selected IDs
  - `:all` - All items selected
  - `{:all_except, list()}` - All items except the excluded ones
  """
  @callback get_selected_ids(state :: state()) :: list() | :all | {:all_except, list()}

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.SelectionHandler

      alias MishkaGervaz.Table.Web.State

      @impl true
      @spec toggle_select(State.t(), binary()) :: State.t()
      def toggle_select(state, id) do
        if state.select_all? do
          excluded_ids =
            if MapSet.member?(state.excluded_ids, id) do
              MapSet.delete(state.excluded_ids, id)
            else
              MapSet.put(state.excluded_ids, id)
            end

          State.update(state, excluded_ids: excluded_ids)
        else
          selected_ids =
            if MapSet.member?(state.selected_ids, id) do
              MapSet.delete(state.selected_ids, id)
            else
              MapSet.put(state.selected_ids, id)
            end

          State.update(state, selected_ids: selected_ids)
        end
      end

      @impl true
      @spec toggle_select_all(State.t()) :: State.t()
      def toggle_select_all(state) do
        if state.select_all? do
          State.update(state,
            select_all?: false,
            selected_ids: MapSet.new(),
            excluded_ids: MapSet.new()
          )
        else
          State.update(state,
            select_all?: true,
            selected_ids: MapSet.new(),
            excluded_ids: MapSet.new()
          )
        end
      end

      @impl true
      @spec clear_selection(State.t()) :: State.t()
      def clear_selection(state) do
        State.update(state,
          selected_ids: MapSet.new(),
          excluded_ids: MapSet.new(),
          select_all?: false
        )
      end

      @impl true
      @spec get_selected_ids(State.t()) :: list() | :all | {:all_except, list()}
      def get_selected_ids(state) do
        cond do
          state.select_all? and MapSet.size(state.excluded_ids) > 0 ->
            {:all_except, MapSet.to_list(state.excluded_ids)}

          state.select_all? ->
            :all

          true ->
            MapSet.to_list(state.selected_ids)
        end
      end

      defoverridable toggle_select: 2,
                     toggle_select_all: 1,
                     clear_selection: 1,
                     get_selected_ids: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.SelectionHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.SelectionHandler
end

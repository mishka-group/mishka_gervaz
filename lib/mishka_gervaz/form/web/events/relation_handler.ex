defmodule MishkaGervaz.Form.Web.Events.RelationHandler do
  @moduledoc """
  Handles relation field events (search, select, clear).

  ## Overridable Functions

  - `handle_search/4` - Search relation options
  - `handle_select/4` - Select a relation value
  - `handle_clear/3` - Clear a relation selection

  ## User Override

      defmodule MyApp.Form.RelationHandler do
        use MishkaGervaz.Form.Web.Events.RelationHandler

        def handle_search(state, field_name, search_term, socket) do
          # Custom search logic
          super(state, field_name, search_term, socket)
        end
      end
  """

  alias MishkaGervaz.Form.Web.{State, DataLoader}

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.{State, DataLoader}

      @doc """
      Search relation options with a query string.
      """
      @spec handle_search(State.t(), atom(), String.t(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def handle_search(state, field_name, search_term, socket) do
        DataLoader.search_relation_options(socket, state, field_name, search_term)
      end

      @doc """
      Handle selection of a relation value.

      Updates the field_values with the selected value.
      """
      @spec handle_select(State.t(), atom(), String.t(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def handle_select(state, field_name, value, socket) do
        field_values = Map.put(state.field_values, field_name, value)
        state = State.update(state, field_values: field_values, dirty?: true)
        Phoenix.Component.assign(socket, :form_state, state)
      end

      @doc """
      Clear a relation selection.
      """
      @spec handle_clear(State.t(), atom(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def handle_clear(state, field_name, socket) do
        field_values = Map.delete(state.field_values, field_name)

        relation_options =
          Map.update(state.relation_options, field_name, %{}, fn opt ->
            Map.delete(opt, :selected)
          end)

        state =
          State.update(state, field_values: field_values, relation_options: relation_options)

        Phoenix.Component.assign(socket, :form_state, state)
      end

      defoverridable handle_search: 4,
                     handle_select: 4,
                     handle_clear: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.RelationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.RelationHandler
end

defmodule MishkaGervaz.Table.Web.DataLoader.TenantResolver do
  @moduledoc """
  Resolves tenant and read actions based on state.

  ## Overridable Functions

  - `get_tenant/1` - Get tenant from state
  - `get_read_action/1` - Get read action based on archive status
  - `get_archive_read_action/1` - Get specific archive read action

  ## User Override

      defmodule MyApp.Table.DataLoader.TenantResolver do
        use MishkaGervaz.Table.Web.DataLoader.TenantResolver

        def get_tenant(state) do
          # Use organization_id instead of site_id
          if state.master_user? do
            nil
          else
            Map.get(state.current_user, :organization_id)
          end
        end
      end
  """

  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Resource.Info.Table, as: Info

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.DataLoader.Builder

      alias MishkaGervaz.Table.Web.State
      alias MishkaGervaz.Resource.Info.Table, as: Info

      @doc """
      Get tenant from state. Returns nil for master users.
      """
      @spec get_tenant(State.t()) :: any()
      def get_tenant(%State{master_user?: true}), do: nil
      def get_tenant(%State{current_user: user}), do: Map.get(user, :site_id)

      @doc """
      Get read action based on archive status.
      """
      @spec get_read_action(State.t()) :: atom()
      def get_read_action(%State{archive_status: :archived} = state) do
        get_archive_read_action(state)
      end

      def get_read_action(state) do
        State.get_action(state, :read)
      end

      @doc """
      Get archive-specific read action.
      """
      @spec get_archive_read_action(State.t()) :: atom()
      def get_archive_read_action(state) do
        case Info.archive_action_for(state.static.resource, :read, state.master_user?) do
          nil -> State.get_action(state, :read)
          action -> action
        end
      end

      defoverridable get_tenant: 1,
                     get_read_action: 1,
                     get_archive_read_action: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.TenantResolver.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.TenantResolver
end

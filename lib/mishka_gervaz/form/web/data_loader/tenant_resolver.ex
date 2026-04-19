defmodule MishkaGervaz.Form.Web.DataLoader.TenantResolver do
  @moduledoc """
  Resolves tenant and actions for form operations.

  ## Overridable Functions

  - `get_tenant/1` - Get tenant from form state
  - `get_create_action/1` - Get create action based on user type
  - `get_update_action/1` - Get update action based on user type
  - `get_read_action/1` - Get read action based on user type

  ## User Override

      defmodule MyApp.Form.TenantResolver do
        use MishkaGervaz.Form.Web.DataLoader.TenantResolver

        def get_tenant(state) do
          if state.master_user? do
            nil
          else
            Map.get(state.current_user, :organization_id)
          end
        end
      end
  """

  alias MishkaGervaz.Form.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.DataLoader.Builder

      alias MishkaGervaz.Form.Web.State

      @doc """
      Get tenant from state. Returns nil for master users.
      """
      @spec get_tenant(State.t()) :: any()
      def get_tenant(%State{master_user?: true}), do: nil
      def get_tenant(%State{current_user: user}), do: Map.get(user, :site_id)

      @doc """
      Get create action for the resource.
      """
      @spec get_create_action(State.t()) :: atom()
      def get_create_action(state) do
        State.get_action(state, :create)
      end

      @doc """
      Get update action for the resource.
      """
      @spec get_update_action(State.t()) :: atom()
      def get_update_action(state) do
        State.get_action(state, :update)
      end

      @doc """
      Get read action for the resource.
      """
      @spec get_read_action(State.t()) :: atom()
      def get_read_action(state) do
        State.get_action(state, :read)
      end

      defoverridable get_tenant: 1, get_create_action: 1, get_update_action: 1, get_read_action: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.DataLoader.TenantResolver.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.DataLoader.TenantResolver
end

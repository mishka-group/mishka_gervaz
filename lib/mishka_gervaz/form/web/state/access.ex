defmodule MishkaGervaz.Form.Web.State.Access do
  @moduledoc """
  Handles access control for form operations.

  ## Overridable Functions

  - `master_user?/1` - Check if user is a master user
  - `get_action/3` - Get appropriate Ash action for context
  - `get_preloads/2` - Get all preloads needed
  - `get_tenant/1` - Get tenant from user

  ## User Override

      defmodule MyApp.Form.Access do
        use MishkaGervaz.Form.Web.State.Access

        def master_user?(%{role: :admin}), do: true
        def master_user?(user), do: super(user)
      end
  """

  alias MishkaGervaz.Resource.Info.Form, as: Info

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.State.Builder

      alias MishkaGervaz.Resource.Info.Form, as: Info

      @doc """
      Checks if user is a master user (has global access).
      """
      @spec master_user?(map()) :: boolean()
      def master_user?(%{site_id: nil}), do: true

      @spec master_user?(term()) :: boolean()
      def master_user?(_), do: false

      @doc """
      Gets the appropriate Ash action for the given context.
      """
      @spec get_action(module(), atom(), boolean()) :: atom()
      def get_action(resource, action_type, master_user?) do
        Info.action_for(resource, action_type, master_user?)
      end

      @doc """
      Gets all preloads needed for the resource form.
      """
      @spec get_preloads(module(), boolean()) :: list()
      def get_preloads(resource, master_user?) do
        Info.all_preloads(resource, master_user?)
      end

      @doc """
      Gets the tenant value from the user.
      """
      @spec get_tenant(map() | nil) :: any()
      def get_tenant(%{site_id: site_id}), do: site_id
      def get_tenant(_), do: nil

      defoverridable master_user?: 1,
                     get_action: 3,
                     get_preloads: 2,
                     get_tenant: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.Access.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.Access
end

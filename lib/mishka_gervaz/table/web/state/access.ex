defmodule MishkaGervaz.Table.Web.State.Access do
  @moduledoc """
  Handles access control for records and actions.

  ## Overridable Functions

  - `master_user?/1` - Check if user is a master user
  - `can_modify_record?/2` - Check if user can modify a record
  - `record_visible?/3` - Check if record is visible to user
  - `get_action/3` - Get appropriate Ash action for context
  - `get_preloads/2` - Get all preloads needed

  ## User Override

      defmodule MyApp.Table.Access do
        use MishkaGervaz.Table.Web.State.Access

        def master_user?(%{role: :admin}), do: true
        def master_user?(user), do: super(user)
      end
  """

  alias MishkaGervaz.Resource.Info.Table, as: Info

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.State.Builder

      alias MishkaGervaz.Resource.Info.Table, as: Info

      @doc """
      Checks if user is a master user (has global access).

      ## Parameters

        - `user` - The user map to check

      ## Returns

        - `true` if user is a master user, `false` otherwise
      """
      @spec master_user?(map()) :: boolean()
      def master_user?(%{site_id: nil}), do: true

      @spec master_user?(term()) :: boolean()
      def master_user?(_), do: false

      @doc """
      Checks if user can modify a record based on tenant permissions.

      ## Parameters

        - `master_user?` - Whether the user is a master user
        - `user` - The user map
        - `record` - The record to check modification access for

      ## Returns

        - `true` if user can modify the record, `false` otherwise
      """
      @spec can_modify_record?(boolean(), map(), struct()) :: boolean()
      def can_modify_record?(true, _user, _record), do: true

      @spec can_modify_record?(boolean(), map(), struct()) :: boolean()
      def can_modify_record?(false, user, record) do
        case get_tenant_field(record) do
          nil ->
            true

          tenant_field ->
            user_tenant = Map.get(user, tenant_field)
            record_tenant = Map.get(record, tenant_field)
            user_tenant != nil and record_tenant == user_tenant
        end
      end

      @doc """
      Checks if a record is visible to a user.

      ## Parameters

        - `master_user?` - Whether the user is a master user
        - `config` - The table configuration map
        - `user` - The user map
        - `record` - The record to check visibility for

      ## Returns

        - `true` if record is visible, `false` otherwise
      """
      @spec record_visible?(boolean(), map(), map(), struct()) :: boolean()
      def record_visible?(true, _config, _user, _record), do: true

      @spec record_visible?(boolean(), map(), map(), struct()) :: boolean()
      def record_visible?(false, config, user, record) do
        case get_in(config, [:realtime, :visible]) do
          func when is_function(func, 2) -> func.(record, user)
          _ -> default_record_visible?(record, user)
        end
      end

      @doc """
      Gets the appropriate Ash action for the given context.

      ## Parameters

        - `resource` - The Ash resource module
        - `action_type` - The type of action (:read, :create, :update, :destroy)
        - `master_user?` - Whether the user is a master user

      ## Returns

        - The action name atom
      """
      @spec get_action(module(), atom(), boolean()) :: atom()
      def get_action(resource, action_type, master_user?) do
        Info.action_for(resource, action_type, master_user?)
      end

      @doc """
      Gets all preloads needed for the resource.

      ## Parameters

        - `resource` - The Ash resource module
        - `master_user?` - Whether the user is a master user

      ## Returns

        - A list of preload specifications
      """
      @spec get_preloads(module(), boolean()) :: list()
      def get_preloads(resource, master_user?) do
        Info.all_preloads(resource, master_user?)
      end

      @spec get_tenant_field(struct()) :: atom() | nil
      defp get_tenant_field(record) when is_struct(record) do
        Ash.Resource.Info.multitenancy_attribute(record.__struct__)
      end

      @spec get_tenant_field(term()) :: nil
      defp get_tenant_field(_), do: nil

      @spec default_record_visible?(struct(), map()) :: boolean()
      defp default_record_visible?(record, user) do
        case get_tenant_field(record) do
          nil ->
            true

          tenant_field ->
            user_tenant = Map.get(user, tenant_field)
            is_nil(user_tenant) or Map.get(record, tenant_field) in [nil, user_tenant]
        end
      end

      defoverridable master_user?: 1,
                     can_modify_record?: 3,
                     record_visible?: 4,
                     get_action: 3,
                     get_preloads: 2
    end
  end
end

defmodule MishkaGervaz.Table.Web.State.Access.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.Access
end

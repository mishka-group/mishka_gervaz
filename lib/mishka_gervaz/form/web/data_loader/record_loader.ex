defmodule MishkaGervaz.Form.Web.DataLoader.RecordLoader do
  @moduledoc """
  Loads records for edit mode and creates AshPhoenix.Form for forms.

  ## Overridable Functions

  - `load_for_edit/3` - Load a record and build an AshPhoenix.Form for editing
  - `new_for_create/2` - Build an empty AshPhoenix.Form for creating
  - `build_form/3` - Build an AshPhoenix.Form from a record or resource

  ## User Override

      defmodule MyApp.Form.RecordLoader do
        use MishkaGervaz.Form.Web.DataLoader.RecordLoader

        def load_for_edit(state, record_id, opts) do
          # Custom loading with extra preloads
          super(state, record_id, opts)
        end
      end
  """

  alias MishkaGervaz.Form.Web.State
  alias MishkaGervaz.Resource.Info.Form, as: Info

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.DataLoader.Builder

      alias MishkaGervaz.Form.Web.State
      alias MishkaGervaz.Resource.Info.Form, as: Info

      @doc """
      Load a record by ID and build an AshPhoenix.Form for editing.

      ## Options

      - `:tenant` - Tenant value for multi-tenant resources
      - `:actor` - The actor performing the action
      """
      @spec load_for_edit(State.t(), String.t(), keyword()) ::
              {:ok, Phoenix.HTML.Form.t()} | {:error, term()}
      def load_for_edit(state, record_id, opts \\ []) do
        resource = state.static.resource
        read_action = State.get_action(state, :read)
        update_action = State.get_action(state, :update)
        preloads = State.get_preloads(state)
        tenant = Keyword.get(opts, :tenant)
        actor = Keyword.get(opts, :actor, state.current_user)

        read_opts =
          [action: read_action, actor: actor, load: preloads]
          |> maybe_add_tenant(tenant)

        case Ash.get(resource, record_id, read_opts) do
          {:ok, record} ->
            effective_tenant = tenant || resolve_tenant_from_record(resource, record)

            build_form(state, record, :update,
              action: update_action,
              actor: actor,
              tenant: effective_tenant
            )

          {:error, reason} ->
            {:error, reason}
        end
      end

      @doc """
      Build an empty AshPhoenix.Form for creating a new record.
      """
      @spec new_for_create(State.t(), keyword()) ::
              {:ok, Phoenix.HTML.Form.t()} | {:error, term()}
      def new_for_create(state, opts \\ []) do
        create_action = State.get_action(state, :create)
        actor = Keyword.get(opts, :actor, state.current_user)
        tenant = Keyword.get(opts, :tenant)

        build_form(state, state.static.resource, :create,
          action: create_action,
          actor: actor,
          tenant: tenant
        )
      end

      @doc """
      Build an AshPhoenix.Form from a record (for edit) or resource (for create).
      """
      @spec build_form(State.t(), module() | struct(), :create | :update, keyword()) ::
              {:ok, Phoenix.HTML.Form.t()} | {:error, term()}
      def build_form(_state, resource_or_record, type, opts) do
        action = Keyword.get(opts, :action)
        actor = Keyword.get(opts, :actor)
        tenant = Keyword.get(opts, :tenant)

        form_opts =
          [as: "form"]
          |> maybe_add_opt(:actor, actor)
          |> maybe_add_opt(:tenant, tenant)

        try do
          form =
            case type do
              :create ->
                AshPhoenix.Form.for_create(resource_or_record, action, form_opts)

              :update ->
                AshPhoenix.Form.for_update(resource_or_record, action, form_opts)
            end

          {:ok, Phoenix.Component.to_form(form)}
        rescue
          e -> {:error, e}
        end
      end

      @spec maybe_add_tenant(keyword(), any()) :: keyword()
      defp maybe_add_tenant(opts, nil), do: opts
      defp maybe_add_tenant(opts, tenant), do: Keyword.put(opts, :tenant, tenant)

      @spec maybe_add_opt(keyword(), atom(), any()) :: keyword()
      defp maybe_add_opt(opts, _key, nil), do: opts
      defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)

      defp resolve_tenant_from_record(resource, record) do
        case Ash.Resource.Info.multitenancy_attribute(resource) do
          nil -> nil
          attr -> Map.get(record, attr)
        end
      end

      defoverridable load_for_edit: 2,
                     load_for_edit: 3,
                     new_for_create: 1,
                     new_for_create: 2,
                     build_form: 4
    end
  end
end

defmodule MishkaGervaz.Form.Web.DataLoader.RecordLoader.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.DataLoader.RecordLoader
end

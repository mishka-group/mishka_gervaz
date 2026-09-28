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

  `keyword_put_if_set/3`, `resolve_tenant_from_record/2` and `action_of_type/3` are public
  helpers an override can reuse.

  See `MishkaGervaz.Form.Web.DataLoader`,
  `MishkaGervaz.Form.Web.DataLoader.Helpers`,
  `MishkaGervaz.Form.Web.State` (for `State.get_action/2` and
  `State.get_preloads/1`), and the sibling sub-builders `RelationLoader`,
  `TenantResolver`, `HookRunner`.
  """

  @doc false
  @spec keyword_put_if_set(keyword(), atom(), any()) :: keyword()
  def keyword_put_if_set(opts, _key, nil), do: opts
  def keyword_put_if_set(opts, key, value), do: Keyword.put(opts, key, value)

  @doc false
  @spec form_id(map()) :: String.t() | nil
  def form_id(%{static: %{id: id}}) when is_binary(id), do: id <> "-form"
  def form_id(_), do: nil

  @doc false
  @spec resolve_tenant_from_record(module(), map()) :: any() | nil
  def resolve_tenant_from_record(resource, record) do
    case Ash.Resource.Info.multitenancy_attribute(resource) do
      nil -> nil
      attr -> Map.get(record, attr)
    end
  end

  @doc false
  @spec action_of_type(module() | struct(), atom(), :create | :update) :: struct() | nil
  def action_of_type(%resource{}, action, type), do: action_of_type(resource, action, type)

  def action_of_type(resource, action, type) when is_atom(resource) and is_atom(action) do
    case Ash.Resource.Info.action(resource, action) do
      %{type: ^type} = found -> found
      _ -> nil
    end
  end

  def action_of_type(_resource, _action, _type), do: nil

  defmacro __using__(_opts) do
    quote do
      alias MishkaGervaz.Form.Web.State
      alias MishkaGervaz.Resource.Info.Form, as: Info

      import MishkaGervaz.Form.Web.DataLoader.RecordLoader,
        only: [
          keyword_put_if_set: 3,
          form_id: 1,
          resolve_tenant_from_record: 2,
          action_of_type: 3
        ]

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
          |> keyword_put_if_set(:tenant, tenant)

        case Ash.get(resource, record_id, read_opts) do
          {:ok, record} ->
            record = MishkaGervaz.Helpers.inject_preload_aliases(record, state.preload_aliases)

            effective_tenant =
              if state.master_user? do
                nil
              else
                tenant || resolve_tenant_from_record(resource, record)
              end

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

      Returns `{:error, {:no_such_action, action}}` when the resource has no `type` action named
      `action`. Anything else that fails while the form is built raises.
      """
      @spec build_form(State.t(), module() | struct(), :create | :update, keyword()) ::
              {:ok, Phoenix.HTML.Form.t()} | {:error, term()}
      def build_form(state, resource_or_record, type, opts) do
        action = Keyword.get(opts, :action)
        actor = Keyword.get(opts, :actor)
        tenant = Keyword.get(opts, :tenant)

        form_opts =
          [as: "form"]
          |> keyword_put_if_set(:id, form_id(state))
          |> keyword_put_if_set(:actor, actor)
          |> keyword_put_if_set(:tenant, tenant)

        case {type, action_of_type(resource_or_record, action, type)} do
          {_type, nil} ->
            {:error, {:no_such_action, action}}

          {:create, _action} ->
            {:ok,
             resource_or_record
             |> AshPhoenix.Form.for_create(action, form_opts)
             |> Phoenix.Component.to_form()}

          {:update, _action} ->
            {:ok,
             resource_or_record
             |> AshPhoenix.Form.for_update(action, form_opts)
             |> Phoenix.Component.to_form()}
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

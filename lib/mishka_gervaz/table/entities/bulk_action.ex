defmodule MishkaGervaz.Table.Entities.BulkAction do
  @moduledoc """
  Entity struct for bulk action configuration.
  """

  @type action_type :: :event | :destroy | :update | :unarchive | :permanent_destroy

  @type handler ::
          :parent
          | {:type, action_type()}
          | (list() | :all | {:all_except, list()}, map() -> {:ok, map()} | {:error, term()})
          | atom()
          | {atom(), atom()}

  @type t :: %__MODULE__{
          name: atom(),
          type: action_type() | nil,
          action: atom() | {atom(), atom()} | nil,
          confirm: boolean() | String.t() | nil,
          event: atom() | nil,
          payload: (MapSet.t() -> map()) | nil,
          restricted: boolean(),
          visible: :active | :archived | (map() -> boolean()),
          handler: handler() | nil,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  @builtin_action_types [:event, :destroy, :update, :unarchive, :permanent_destroy]

  defstruct [
    :name,
    :__identifier__,
    :type,
    :action,
    confirm: nil,
    event: nil,
    payload: nil,
    restricted: false,
    visible: :active,
    handler: :parent,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Action identifier."
    ],
    type: [
      type: {:in, @builtin_action_types},
      doc: """
      Built-in action type. When set, the handler is automatically resolved.

      Built-in types:
      - `:event` - Send event to parent LiveView (uses `event` option or action name)
      - `:destroy` - Soft delete records (uses source.actions.destroy)
      - `:update` - Run update action (uses `action` option)
      - `:unarchive` - Restore archived records (uses archive.actions.restore)
      - `:permanent_destroy` - Permanently delete archived records (uses archive.actions.destroy)

      When `type` is set, you don't need to specify `handler` - it will be resolved automatically.
      If both `type` and `handler` are set, `handler` takes precedence.
      """
    ],
    action: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: """
      Ash action to execute for `:update` type.
      Can be an atom (single action) or tuple {master_action, tenant_action}.
      """
    ],
    confirm: [
      type: {:or, [:boolean, :string]},
      doc: "Confirmation message ({count} interpolated)."
    ],
    event: [
      type: :atom,
      doc: "Event name for `:event` type. Defaults to action name if not specified."
    ],
    payload: [
      type: {:fun, 1},
      doc: "Payload function `fn selected_ids -> payload`."
    ],
    restricted: [
      type: :boolean,
      default: false,
      doc: "Permission check."
    ],
    visible: [
      type: {:or, [{:in, [:active, :archived]}, {:fun, 1}]},
      default: :active,
      doc:
        "Show only when viewing :active or :archived records, or a function `fn state -> boolean`."
    ],
    handler: [
      type: {:or, [:atom, {:fun, 2}, {:tuple, [:atom, :atom]}]},
      default: :parent,
      doc: """
      Handler for bulk action execution:
      - `:parent` - Send to parent LiveView
      - `fn selected_ids, state -> {:ok, state} end` - Custom function
      - `:action_name` - Single Ash action
      - `{:master_action, :tenant_action}` - Master/tenant Ash actions

      Note: If `type` is set, handler is resolved automatically.
      """
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc false
  def builtin_action_types, do: @builtin_action_types

  @doc """
  Transform the bulk action after DSL compilation.

  If `type` is set and `handler` is still the default `:parent`,
  marks the handler as type-based for runtime resolution.
  """
  def transform(%__MODULE__{type: type, handler: :parent} = action) when not is_nil(type) do
    {:ok, %{action | handler: {:type, type}}}
  end

  def transform(action), do: {:ok, action}
end

defmodule MishkaGervaz.Table.Entities.BulkAction.Ui do
  @moduledoc """
  UI configuration for a bulk action.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          icon: String.t() | nil,
          class: String.t() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            icon: nil,
            class: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Button label. String or `fn -> \"Label\" end` for gettext."
    ],
    icon: [
      type: :string,
      doc: "Icon identifier."
    ],
    class: [
      type: :string,
      doc: "CSS classes."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Template-specific options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end

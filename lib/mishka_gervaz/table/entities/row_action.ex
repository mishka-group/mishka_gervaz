defmodule MishkaGervaz.Table.Entities.RowAction do
  @moduledoc """
  Entity struct for row action configuration.
  """

  @type action_type ::
          :link
          | :modal
          | :event
          | :destroy
          | :update
          | :accordion
          | :unarchive
          | :permanent_destroy
          | :row_click

  @type t :: %__MODULE__{
          name: atom(),
          type: action_type(),
          path: String.t() | (map() -> String.t()) | nil,
          event: atom() | String.t() | nil,
          action: atom() | {atom(), atom()} | nil,
          payload: (map() -> map()) | nil,
          confirm: String.t() | (map() -> String.t()) | nil,
          restricted: boolean(),
          visible: boolean() | :active | :archived | (map(), map() -> boolean()),
          render:
            (map() -> any()) | (map(), map() -> any()) | (map(), map(), any() -> any()) | nil,
          ui: __MODULE__.Ui.t() | nil,
          type_module: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    :type,
    path: nil,
    event: nil,
    action: nil,
    payload: nil,
    confirm: nil,
    restricted: false,
    visible: :active,
    render: nil,
    ui: nil,
    type_module: nil,
    __spark_metadata__: nil
  ]

  @builtin_action_types [
    :link,
    :modal,
    :event,
    :destroy,
    :update,
    :accordion,
    :unarchive,
    :permanent_destroy,
    :row_click
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Action identifier."
    ],
    type: [
      type:
        {:or,
         [{:in, @builtin_action_types}, {:behaviour, MishkaGervaz.Table.Behaviours.ActionType}]},
      required: true,
      doc: """
      Action type. Can be a built-in type atom or a custom module implementing ActionType behaviour.

      Built-in types: #{Enum.map_join(@builtin_action_types, ", ", &inspect/1)}

      Use :row_click to make entire row clickable.

      Custom type example:
          action :archive, type: MyApp.Table.Actions.Archive
      """
    ],
    path: [
      type: {:or, [:string, {:fun, 1}]},
      doc: "Link path (supports {field} interpolation)."
    ],
    event: [
      type: {:or, [:atom, :string]},
      doc: "Event name to send."
    ],
    action: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: """
      Ash action to execute for :update type.
      Can be an atom (single action) or tuple {master_action, tenant_action}.

      Example:
          action :activate, type: :update, action: :activate
          action :activate, type: :update, action: {:master_activate, :activate}
      """
    ],
    payload: [
      type: {:fun, 1},
      doc: "Event payload function `fn record -> payload`."
    ],
    confirm: [
      type: {:or, [:string, {:fun, 1}]},
      doc: "Confirmation message (supports {field} interpolation)."
    ],
    restricted: [
      type: :boolean,
      default: false,
      doc: "Only show if user can modify record."
    ],
    visible: [
      type: {:or, [:boolean, {:in, [:active, :archived]}, {:fun, 2}]},
      default: :active,
      doc:
        "When action is visible. `:active` (default) - only for active records, `:archived` - only for archived records, `true` - always visible, `false` - never visible, `fn/2` - custom function."
    ],
    render: [
      type: {:or, [{:fun, 1}, {:fun, 2}, {:fun, 3}]},
      doc:
        "Custom HEEx render function. `fn record -> ... end`, `fn record, action -> ... end`, or `fn record, action, target -> ... end`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the row action after DSL compilation.
  """
  def transform(%__MODULE__{} = action) do
    action = resolve_type_module(action)
    {:ok, action}
  end

  def transform(action), do: {:ok, action}

  defp resolve_type_module(%{type: type} = action) do
    type_module = MishkaGervaz.Table.Types.Action.get_or_passthrough(type)
    %{action | type_module: type_module}
  end
end

defmodule MishkaGervaz.Table.Entities.RowAction.Ui do
  @moduledoc """
  UI configuration for a row action.
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
      doc:
        "Button label. String or `fn -> \"Label\" end` for gettext. Defaults to humanized action name."
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

defmodule MishkaGervaz.Table.Entities.RowActionDropdown do
  @moduledoc """
  Entity struct for a dropdown menu containing row actions.
  """

  @type t :: %__MODULE__{
          name: atom(),
          items: list(),
          ui: MishkaGervaz.Table.Entities.RowAction.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    items: [],
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Dropdown identifier."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(dropdown), do: {:ok, dropdown}
end

defmodule MishkaGervaz.Table.Entities.DropdownSeparator do
  @moduledoc """
  Entity struct for a separator in dropdown menus.
  """

  @type t :: %__MODULE__{
          label: String.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: :string,
      doc: "Optional separator label."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(separator), do: {:ok, separator}
end

defmodule MishkaGervaz.Table.Entities.RowAction do
  @moduledoc """
  Entity struct for row action configuration.

  See `MishkaGervaz.Table.Dsl.RowActions`,
  `MishkaGervaz.Table.Entities.RowAction.Ui`,
  `MishkaGervaz.Table.Entities.RowActionDropdown`,
  `MishkaGervaz.Table.Entities.DropdownSeparator`,
  `MishkaGervaz.Table.Types.Action` (type registry), and
  `MishkaGervaz.Table.Web.State.ActionBuilder`.
  """

  @type action_type ::
          :link
          | :modal
          | :event
          | :edit
          | :destroy
          | :update
          | :accordion
          | :unarchive
          | :permanent_destroy
          | :row_click
          | :drawer

  @type t :: %__MODULE__{
          name: atom(),
          type: action_type(),
          path: String.t() | (map() -> String.t()) | nil,
          event: atom() | String.t() | nil,
          action: atom() | {atom(), atom()} | nil,
          payload: (map() -> map()) | nil,
          confirm: String.t() | (map() -> String.t()) | keyword() | nil,
          restricted: boolean(),
          visible: boolean() | :active | :archived | (map(), map() -> boolean()),
          js: (map() -> Phoenix.LiveView.JS.t()) | nil,
          render:
            (map() -> any()) | (map(), map() -> any()) | (map(), map(), any() -> any()) | nil,
          open: :form | (map() -> any()) | (map(), map() -> any()) | nil,
          drawer: keyword(),
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
    js: nil,
    render: nil,
    open: nil,
    drawer: [],
    ui: nil,
    type_module: nil,
    __spark_metadata__: nil
  ]

  @builtin_action_types [
    :link,
    :modal,
    :event,
    :edit,
    :destroy,
    :update,
    :accordion,
    :unarchive,
    :permanent_destroy,
    :row_click,
    :drawer
  ]

  @drawer_tones [:info, :ok, :warn, :danger, :mute]

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

      Use :row_click to make entire row clickable, and :drawer to open the row in the table's
      drawer (see `open` and `drawer`).

      Custom type example:
          action :archive, type: MyApp.Table.Actions.Archive
      """
    ],
    path: [
      type: {:or, [:string, {:fun, 1}]},
      doc:
        "Link path (supports {field} interpolation). A `:link` named `:show`, `:show_link`, `:edit` or `:edit_link` may leave it out: its address is built from the table's route, `{route}/{id}` or `{route}/{id}/edit`."
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
      type: {:or, [:string, {:fun, 1}, {:keyword_list, MishkaGervaz.Question.schema("the row")}]},
      doc: """
      A question asked before the action runs. A string or `fn record -> string end` is the
      browser's own question (`data-confirm`). A keyword list is asked in the UI adapter's question
      window: `title`, `body`, `tone` (`:danger`, `:warn`, `:info`), `answer` (a word to type before
      the button answers, such as the row's name), `answer_label`, `confirm_label` and
      `cancel_label`, each a string or `fn record -> string end`. See `MishkaGervaz.Question`.
      """
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
    js: [
      type: {:fun, 1},
      doc: "Optional JS commands to chain onto the button click. `fn record -> JS.exec(...) end`."
    ],
    render: [
      type: {:or, [{:fun, 1}, {:fun, 2}, {:fun, 3}]},
      doc:
        "Custom HEEx render function. `fn record -> ... end`, `fn record, action -> ... end`, or `fn record, action, target -> ... end`."
    ],
    open: [
      type: {:or, [{:in, [:form]}, {:fun, 1}, {:fun, 2}]},
      doc: """
      What a `:drawer` action opens in the table's drawer for the row: `:form`, the resource's
      own form editing the row, or a record view, `fn record -> ~H"..." end` (or
      `fn record, state -> ... end`).
      """
    ],
    drawer: [
      type: :keyword_list,
      default: [],
      doc: """
      The head of a `:drawer` action's drawer: `kind` (`:drawer`, the default, or `:sheet`),
      `title`, `sub` (the line under it), `icon` (a heroicon drawn in a tile), `tone` (`:info`,
      `:ok`, `:warn`, `:danger` or `:mute`), `chips` (labels or `{tone, label}` pairs),
      `actions` (buttons, `fn record -> ~H"..." end`) and `actions_at` (`:foot` or `:head`).
      Each value but `kind` and `actions_at` is a value or `fn record -> value end`; a string is
      translated.
      """,
      keys: [
        kind: [
          type: {:in, [:drawer, :sheet]},
          default: :drawer,
          doc: "`:drawer`, a panel from the side, or `:sheet`, a bottom sheet."
        ],
        title: [type: {:or, [:string, {:fun, 1}]}, doc: "The heading."],
        sub: [type: {:or, [:string, {:fun, 1}]}, doc: "The line under the heading."],
        icon: [
          type: {:or, [:string, {:fun, 1}]},
          doc: "A heroicon name drawn in a tile before the heading."
        ],
        tone: [
          type: {:or, [{:in, @drawer_tones}, {:fun, 1}]},
          doc: "The tile's colours: #{Enum.map_join(@drawer_tones, ", ", &inspect/1)}."
        ],
        chips: [
          type: {:or, [{:list, :any}, {:fun, 1}]},
          doc: "Chips under the heading, each a label or a `{tone, label}` pair."
        ],
        actions: [
          type: {:or, [{:fun, 1}, {:fun, 2}]},
          doc: "Buttons, `fn record -> ~H\"...\" end`, drawn in the drawer's foot."
        ],
        actions_at: [
          type: {:in, [:foot, :head]},
          default: :foot,
          doc: "Where the buttons go: `:foot` or `:head`, beside the close button."
        ]
      ]
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

  @doc false
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

  @doc false
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

  @doc false
  def transform(separator), do: {:ok, separator}
end

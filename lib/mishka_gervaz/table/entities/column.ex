defmodule MishkaGervaz.Table.Entities.Column do
  @moduledoc """
  Entity struct for table column configuration.

  This module defines the struct and schema for columns, following Ash's
  entity pattern with `opt_schema` and `transform/1`.
  """

  @type position :: integer() | :first | :last | {:before, atom()} | {:after, atom()}

  @type source ::
          atom()
          | [atom()]
          | {atom(), atom()}
          | {atom(), [atom()]}
          | [{atom(), atom()} | atom()]

  @type t :: %__MODULE__{
          name: atom(),
          source: source() | nil,
          sortable: boolean(),
          searchable: boolean(),
          filterable: boolean(),
          visible: boolean() | (map() -> boolean()),
          position: position() | nil,
          export: boolean(),
          export_as: atom() | nil,
          default: any(),
          separator: String.t(),
          static: boolean(),
          requires: [atom()],
          format: (any() -> any()) | (map(), map(), any() -> any()) | nil,
          render:
            (struct() -> Phoenix.LiveView.Rendered.t())
            | (struct(), map() -> Phoenix.LiveView.Rendered.t())
            | nil,
          sort_field: [atom()],
          label: String.t() | (-> String.t()) | nil,
          ui: __MODULE__.Ui.t() | nil,
          type_module: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    :source,
    sortable: false,
    searchable: false,
    filterable: false,
    visible: true,
    position: nil,
    export: true,
    export_as: nil,
    default: nil,
    separator: " ",
    static: false,
    requires: [],
    sort_field: [],
    format: nil,
    render: nil,
    label: nil,
    ui: nil,
    type_module: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Column identifier."
    ],
    source: [
      type:
        {:or,
         [
           :atom,
           {:tuple, [:atom, :atom]},
           {:tuple, [:atom, {:list, :atom}]},
           {:list, {:or, [:atom, {:tuple, [:atom, :atom]}]}}
         ]},
      doc: """
      Data source for column value. Defaults to column name.

      Formats:
      - `:field` - direct field access (`record.field`)
      - `{:relation, :field}` - nested access (`record.relation.field`)
      - `[:field1, :field2]` - merged fields joined by separator
      - `[{:user, :name}, :title]` - mixed nested and direct fields
      """
    ],
    sortable: [
      type: :boolean,
      default: false,
      doc: "Enable sorting."
    ],
    searchable: [
      type: :boolean,
      default: false,
      doc: "Include in global text search."
    ],
    filterable: [
      type: :boolean,
      default: false,
      doc: "Auto-create filter for this column."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Static or dynamic visibility."
    ],
    position: [
      type: :any,
      doc: "Column position (integer, :first, :last, {:before, :col}, {:after, :col})."
    ],
    export: [
      type: :boolean,
      default: true,
      doc: "Include in CSV/Excel export."
    ],
    export_as: [
      type: :atom,
      doc: "Field name in export. Defaults to column name."
    ],
    default: [
      type: :any,
      doc: "Default value when source is nil."
    ],
    separator: [
      type: :string,
      default: " ",
      doc: "Separator for merged fields."
    ],
    static: [
      type: :boolean,
      default: false,
      doc: "No database source (computed/hardcoded)."
    ],
    requires: [
      type: {:list, :atom},
      default: [],
      doc: "Fields needed for static columns."
    ],
    sort_field: [
      type: {:list, :atom},
      default: [],
      doc:
        "Database field(s) to sort by. Required for static+sortable columns. Supports multiple fields."
    ],
    format: [
      type: {:or, [{:fun, 1}, {:fun, 3}]},
      doc: "Value formatter: `fn value -> ... end` or `fn state, record, value -> ... end`."
    ],
    render: [
      type: {:or, [{:fun, 1}, {:fun, 2}]},
      doc: """
      Custom HEEx render function.

      - 1-arity: `fn record -> ~H"..." end` - receives full record struct
      - 2-arity: `fn record, state -> ~H"..." end` - receives record and state (access `state.master_user?`, `state.current_user`, etc.)
      """
    ],
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Shorthand for ui.label. String or `fn -> gettext(...) end` for i18n."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the column after DSL compilation.

  Sets defaults and resolves the type_module based on ui.type.
  """
  def transform(%__MODULE__{} = column) do
    column =
      column
      |> extract_ui()
      |> maybe_set_source()
      |> resolve_type_module()

    {:ok, column}
  end

  def transform(column), do: {:ok, column}

  # Spark stores nested entities as a list - extract the singleton
  defp extract_ui(%{ui: [ui | _]} = column), do: %{column | ui: ui}
  defp extract_ui(%{ui: ui} = column) when is_struct(ui), do: column
  defp extract_ui(column), do: column

  defp maybe_set_source(%{source: nil, name: name} = column) do
    %{column | source: name}
  end

  defp maybe_set_source(column), do: column

  defp resolve_type_module(%{ui: %{type: type}} = column) when not is_nil(type) do
    type_module = MishkaGervaz.Table.Types.Column.get_or_passthrough(type)
    %{column | type_module: type_module}
  end

  defp resolve_type_module(column), do: column
end

defmodule MishkaGervaz.Table.Entities.Column.Ui do
  @moduledoc """
  UI/presentation configuration for a column.
  """

  @type column_type ::
          :text
          | :boolean
          | :badge
          | :number
          | :currency
          | :percentage
          | :date
          | :datetime
          | :time
          | :link
          | :image
          | :avatar
          | :tags
          | :progress
          | :json
          | :custom

  @type align :: :left | :center | :right

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          type: column_type(),
          width: String.t() | nil,
          min_width: String.t() | nil,
          max_width: String.t() | nil,
          align: align(),
          class: String.t() | nil,
          header_class: String.t() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            type: :text,
            width: nil,
            min_width: nil,
            max_width: nil,
            align: :left,
            class: nil,
            header_class: nil,
            extra: %{},
            __spark_metadata__: nil

  @builtin_column_types [
    :text,
    :boolean,
    :badge,
    :number,
    :currency,
    :percentage,
    :date,
    :datetime,
    :time,
    :link,
    :image,
    :avatar,
    :tags,
    :progress,
    :json,
    :uuid,
    :array,
    :custom
  ]

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Header text. String or `fn -> gettext(...) end` for i18n."
    ],
    type: [
      type:
        {:or,
         [{:in, @builtin_column_types}, {:behaviour, MishkaGervaz.Table.Behaviours.ColumnType}]},
      default: :text,
      doc: """
      Display type. Can be a built-in type atom or a custom module implementing ColumnType behaviour.

      Built-in types: #{Enum.map_join(@builtin_column_types, ", ", &inspect/1)}

      Custom type example:
          column :color do
            ui do
              type MyApp.Table.Types.ColorType
            end
          end
      """
    ],
    width: [
      type: :string,
      doc: "CSS width (e.g., \"200px\", \"20%\")."
    ],
    min_width: [
      type: :string,
      doc: "CSS min-width."
    ],
    max_width: [
      type: :string,
      doc: "CSS max-width."
    ],
    align: [
      type: {:in, [:left, :center, :right]},
      default: :left,
      doc: "Text alignment."
    ],
    class: [
      type: :string,
      doc: "Cell CSS classes."
    ],
    header_class: [
      type: :string,
      doc: "Header cell CSS classes."
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

defmodule MishkaGervaz.Table.Entities.AutoColumns do
  @moduledoc """
  Configuration for auto-discovering columns from Ash resource attributes.
  """

  @type t :: %__MODULE__{
          except: [atom()],
          only: [atom()] | nil,
          position: :start | :end,
          defaults: __MODULE__.Defaults.t() | nil,
          ui_defaults: __MODULE__.UiDefaults.t() | nil,
          overrides: [__MODULE__.Override.t()],
          __spark_metadata__: map() | nil
        }

  defstruct except: [],
            only: nil,
            position: :end,
            defaults: nil,
            ui_defaults: nil,
            overrides: [],
            __spark_metadata__: nil

  @opt_schema [
    except: [
      type: {:list, :atom},
      default: [],
      doc: "Exclude these attributes."
    ],
    only: [
      type: {:list, :atom},
      doc: "Only these attributes (overrides except)."
    ],
    position: [
      type: {:in, [:start, :end]},
      default: :end,
      doc: "Where to place auto columns."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(auto_columns), do: {:ok, auto_columns}
end

defmodule MishkaGervaz.Table.Entities.AutoColumns.Defaults do
  @moduledoc """
  Default options for auto-discovered columns.
  """

  @type t :: %__MODULE__{
          sortable: boolean(),
          searchable: boolean(),
          visible: boolean(),
          export: boolean(),
          __spark_metadata__: map() | nil
        }

  defstruct sortable: false,
            searchable: false,
            visible: true,
            export: true,
            __spark_metadata__: nil

  @opt_schema [
    sortable: [
      type: :boolean,
      default: false,
      doc: "Default sortable value."
    ],
    searchable: [
      type: :boolean,
      default: false,
      doc: "Default searchable value."
    ],
    visible: [
      type: :boolean,
      default: true,
      doc: "Default visible value."
    ],
    export: [
      type: :boolean,
      default: true,
      doc: "Default export value."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(defaults), do: {:ok, defaults}
end

defmodule MishkaGervaz.Table.Entities.AutoColumns.UiDefaults do
  @moduledoc """
  Default UI options for auto-discovered columns.
  """

  @type t :: %__MODULE__{
          boolean_true_label: String.t(),
          boolean_false_label: String.t(),
          datetime_format: atom(),
          text_truncate: integer() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct boolean_true_label: "Yes",
            boolean_false_label: "No",
            datetime_format: :medium,
            text_truncate: nil,
            __spark_metadata__: nil

  @opt_schema [
    boolean_true_label: [
      type: :string,
      default: "Yes",
      doc: "Default label for boolean true."
    ],
    boolean_false_label: [
      type: :string,
      default: "No",
      doc: "Default label for boolean false."
    ],
    datetime_format: [
      type: :atom,
      default: :medium,
      doc: "Default datetime format."
    ],
    text_truncate: [
      type: :integer,
      doc: "Default text truncate length."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui_defaults), do: {:ok, ui_defaults}
end

defmodule MishkaGervaz.Table.Entities.AutoColumns.Override do
  @moduledoc """
  Override configuration for a specific auto-discovered column.
  """

  @type t :: %__MODULE__{
          name: atom(),
          sortable: boolean() | nil,
          searchable: boolean() | nil,
          visible: boolean() | nil,
          export: boolean() | nil,
          format: (any() -> any()) | (map(), map(), any() -> any()) | nil,
          ui: MishkaGervaz.Table.Entities.Column.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    sortable: nil,
    searchable: nil,
    visible: nil,
    export: nil,
    format: nil,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Column name to override."
    ],
    sortable: [
      type: :boolean,
      doc: "Override sortable."
    ],
    searchable: [
      type: :boolean,
      doc: "Override searchable."
    ],
    visible: [
      type: :boolean,
      doc: "Override visible."
    ],
    export: [
      type: :boolean,
      doc: "Override export."
    ],
    format: [
      type: {:or, [{:fun, 1}, {:fun, 3}]},
      doc: "Value formatter: `fn value -> ... end` or `fn state, record, value -> ... end`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(%__MODULE__{} = override) do
    {:ok, extract_ui(override)}
  end

  def transform(override), do: {:ok, override}

  # Spark stores nested entities as a list - extract the singleton
  defp extract_ui(%{ui: [ui | _]} = override), do: %{override | ui: ui}
  defp extract_ui(%{ui: ui} = override) when is_struct(ui), do: override
  defp extract_ui(override), do: override
end

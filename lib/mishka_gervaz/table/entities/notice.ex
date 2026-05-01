defmodule MishkaGervaz.Table.Entities.Notice do
  @moduledoc """
  Entity struct for static table notices (alerts/banners).

  Mirrors `MishkaGervaz.Form.Entities.Notice` but with table-specific
  positions and bind_to atoms.

  ## Positions

  Atoms:
  - `:table_top` - above everything in the table region
  - `:before_header` / `:after_header` - around the table header
  - `:before_filters` / `:after_filters` - around the filters bar
  - `:before_bulk_actions` / `:after_bulk_actions` - around the bulk action bar
  - `:before_table` / `:after_table` - around the `<table>` element itself
  - `:before_pagination` / `:after_pagination` - around the pagination row
  - `:table_bottom` - last possible slot inside the table region
  - `:empty_state` - rendered only when the stream is empty

  Tuples:
  - `{:before_column, :col_name}` / `{:after_column, :col_name}` -
    decorate a specific column header cell

  ## Bind to (dynamic activation)

  - `:no_results` - active when the stream is empty after a load
  - `:has_filters` - active when any filter has a non-empty value
  - `:has_selection` - active when any row is selected
  - `:loading` - active when the table is in `:loading` state
  - `:error` - active when the load returned an error
  - `:archived_view` - active when viewing archived records
  - `nil` - no auto-binding; controlled solely by `visible`/`show_when`

  ## Example

      layout do
        notice :archived_warning do
          position :before_table
          type :warning
          icon "hero-archive-box"
          title "Viewing archived records"
          bind_to :archived_view
        end

        notice :no_match do
          position :empty_state
          type :info
          title "No records match your filters"
          bind_to :no_results
        end
      end
  """

  @valid_types ~w(info warning error success neutral)a
  @valid_position_atoms ~w(
    table_top before_header after_header
    before_filters after_filters
    before_bulk_actions after_bulk_actions
    before_table after_table
    before_pagination after_pagination
    table_bottom empty_state
  )a
  @valid_bind_to ~w(no_results has_filters has_selection loading error archived_view)a

  @type position ::
          :table_top
          | :before_header
          | :after_header
          | :before_filters
          | :after_filters
          | :before_bulk_actions
          | :after_bulk_actions
          | :before_table
          | :after_table
          | :before_pagination
          | :after_pagination
          | :table_bottom
          | :empty_state
          | {:before_column, atom()}
          | {:after_column, atom()}

  @type t :: %__MODULE__{
          name: atom(),
          position: position(),
          type: :info | :warning | :error | :success | :neutral,
          title: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          content: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          icon: String.t() | nil,
          dismissible: boolean(),
          bind_to:
            :no_results
            | :has_filters
            | :has_selection
            | :loading
            | :error
            | :archived_view
            | nil,
          show_when: (map() -> boolean()) | nil,
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          render:
            (map() -> Phoenix.LiveView.Rendered.t())
            | (map(), map() -> Phoenix.LiveView.Rendered.t())
            | nil,
          ui: __MODULE__.Ui.t() | nil,
          __identifier__: atom() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    :title,
    :content,
    :icon,
    :bind_to,
    :show_when,
    :render,
    position: :table_top,
    type: :info,
    dismissible: false,
    visible: true,
    restricted: false,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Unique notice identifier (used for dismiss tracking)."
    ],
    position: [
      type: :any,
      default: :table_top,
      doc:
        "Where the notice is rendered. See module docs for the list of valid atom positions and `{:before_column, name}` / `{:after_column, name}` tuples."
    ],
    type: [
      type: {:in, @valid_types},
      default: :info,
      doc: "Visual style: `:info`, `:warning`, `:error`, `:success`, or `:neutral`."
    ],
    title: [
      type: {:or, [:string, {:fun, 0}, {:fun, 1}]},
      doc: "Notice title. String, `fn -> _ end`, or `fn state -> _ end`."
    ],
    content: [
      type: {:or, [:string, {:fun, 0}, {:fun, 1}]},
      doc: "Notice body. String, `fn -> _ end`, or `fn state -> _ end`."
    ],
    icon: [
      type: :string,
      doc: "Heroicon name."
    ],
    dismissible: [
      type: :boolean,
      default: false,
      doc: "Whether the user can dismiss this notice."
    ],
    bind_to: [
      type: {:in, [nil | @valid_bind_to]},
      doc:
        "Auto-activation source. One of #{inspect(@valid_bind_to)}. When set, the notice renders only when the bound condition is true."
    ],
    show_when: [
      type: {:fun, 1},
      doc: "Custom predicate `fn state -> boolean() end`. Combined with `bind_to` (AND)."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Static or dynamic visibility. `fn state -> boolean() end`."
    ],
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Restrict to master users. `true` or `fn state -> boolean() end`."
    ],
    render: [
      type: {:or, [{:fun, 1}, {:fun, 2}]},
      doc:
        "Custom HEEx render. `fn assigns -> ~H\"...\" end` or `fn assigns, state -> ~H\"...\" end`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc false
  def valid_types, do: @valid_types

  @doc false
  def valid_position_atoms, do: @valid_position_atoms

  @doc false
  def valid_bind_to, do: @valid_bind_to

  @doc """
  Validate a position value. Returns `:ok` or `{:error, reason}`.
  """
  def validate_position(pos) when pos in @valid_position_atoms, do: :ok

  def validate_position({:before_column, col}) when is_atom(col), do: :ok
  def validate_position({:after_column, col}) when is_atom(col), do: :ok

  def validate_position(other),
    do:
      {:error,
       "invalid notice position #{inspect(other)}. Expected one of #{inspect(@valid_position_atoms)} or `{:before_column, atom}` / `{:after_column, atom}`."}

  def transform(%__MODULE__{} = notice) do
    {:ok, extract_ui(notice)}
  end

  def transform(notice), do: {:ok, notice}

  defp extract_ui(%{ui: [ui | _]} = notice), do: %{notice | ui: ui}
  defp extract_ui(%{ui: ui} = notice) when is_struct(ui), do: notice
  defp extract_ui(notice), do: notice
end

defmodule MishkaGervaz.Table.Entities.Notice.Ui do
  @moduledoc """
  UI/presentation configuration for a table notice.
  """

  @type t :: %__MODULE__{
          class: String.t() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct class: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    class: [
      type: :string,
      doc: "CSS classes for the notice wrapper."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional template-specific options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end

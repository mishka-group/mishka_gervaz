defmodule MishkaGervaz.Form.Entities.Notice do
  @moduledoc """
  Static form notice — alerts and banners with a known position,
  validation binding, dismiss tracking, and master-only restriction.

  A notice is declared statically and rendered dynamically: the
  position, type, and binding are pinned at compile time, while
  `visible` / `show_when` / `bind_to` decide whether to actually render
  on each frame. Five visual types (`:info`, `:warning`, `:error`,
  `:success`, `:neutral`) and a custom HEEx render escape hatch cover
  the common cases.

  ## Positions

  Atoms:
  - `:form_top` - above the `<.form>` element.
  - `:before_header` / `:after_header` - around the form header.
  - `:before_groups` / `:before_fields` - before grouped/ungrouped field rows.
  - `:before_submit` - above the submit/cancel row.
  - `:form_bottom` - below the submit row but inside `<.form>`.
  - `:form_footer` - below the form footer (last possible slot).

  Tuples:
  - `{:before_group, :group_name}` / `{:after_group, :group_name}`

  ## Bind to (dynamic activation)

  - `:validation` - shown when `state.form_errors != []`.
  - `:uploads` - shown when any registered upload has errors.
  - `:dirty` - shown when `state.dirty? == true`.
  - `nil` - no auto-binding; controlled solely by `visible`/`show_when`.

  ## Example

      layout do
        notice :read_only_banner do
          position :before_fields
          type :warning
          title "Read-Only Access"
          content "Your role can view but not modify these settings."
          icon "hero-lock-closed"
          visible fn state -> state.current_user.role == :viewer end
          restricted false
          dismissible false
        end

        notice :validation_summary do
          position :form_top
          type :error
          bind_to :validation
          title fn _state -> "Please fix the errors below" end
        end
      end

  See `MishkaGervaz.Form.Dsl.Layout` for the surrounding section and
  `MishkaGervaz.Form.Entities.Notice.Ui` for the `ui` sub-entity.
  """

  alias MishkaGervaz.Form.Entities.Schema

  @valid_types ~w(info warning error success neutral)a
  @valid_position_atoms ~w(
    form_top before_header after_header before_groups before_fields
    before_submit form_bottom form_footer
  )a
  @valid_bind_to ~w(validation uploads dirty)a

  @type position ::
          :form_top
          | :before_header
          | :after_header
          | :before_groups
          | :before_fields
          | :before_submit
          | :form_bottom
          | :form_footer
          | {:before_group, atom()}
          | {:after_group, atom()}

  @type t :: %__MODULE__{
          name: atom(),
          position: position(),
          type: :info | :warning | :error | :success | :neutral,
          title: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          content: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          icon: String.t() | nil,
          dismissible: boolean(),
          bind_to: :validation | :uploads | :dirty | nil,
          show_when: (map() -> boolean()) | nil,
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          only_steps: [atom()] | nil,
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
    :only_steps,
    :render,
    position: :form_top,
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
                  default: :form_top,
                  doc:
                    "Where the notice is rendered. See module docs for the list of valid atom positions and `{:before_group, name}` / `{:after_group, name}` tuples."
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
                    "Auto-activation source. `:validation` (form errors), `:uploads` (upload errors), `:dirty` (dirty form). When set, the notice renders only when the bound condition is true."
                ],
                show_when: [
                  type: {:fun, 1},
                  doc:
                    "Custom predicate `fn state -> boolean() end`. Combined with `bind_to` (AND)."
                ],
                only_steps: [
                  type: {:list, :atom},
                  doc: "Wizard/tabs scoping: only render on these step names."
                ],
                render: [
                  type: {:or, [{:fun, 1}, {:fun, 2}]},
                  doc:
                    "Custom HEEx render. `fn assigns -> ~H\"...\" end` or `fn assigns, state -> ~H\"...\" end`."
                ]
              ] ++ Schema.access_predicates()

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

  def validate_position({:before_group, group}) when is_atom(group), do: :ok
  def validate_position({:after_group, group}) when is_atom(group), do: :ok

  def validate_position(other),
    do:
      {:error,
       "invalid notice position #{inspect(other)}. Expected one of #{inspect(@valid_position_atoms)} or `{:before_group, atom}` / `{:after_group, atom}`."}

  def transform(%__MODULE__{} = notice) do
    {:ok, MishkaGervaz.Helpers.extract_singleton_entity(notice, :ui)}
  end

  def transform(notice), do: {:ok, notice}
end

defmodule MishkaGervaz.Form.Entities.Notice.Ui do
  @moduledoc """
  UI/presentation configuration for a `MishkaGervaz.Form.Entities.Notice`
  — wrapper CSS classes and template-specific extras.
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

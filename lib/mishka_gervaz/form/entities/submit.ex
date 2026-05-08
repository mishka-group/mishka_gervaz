defmodule MishkaGervaz.Form.Entities.Submit.Button do
  @moduledoc """
  Single submit / cancel button configuration.

  Each button (create / update / cancel) is an independent entity with
  its own `label`, `active`, `disabled`, `restricted`, and `visible`
  options. Every option except `label` accepts a boolean or a
  `fn state -> boolean() end` predicate.

  The `active` option is intended for resources: setting `active: false`
  suppresses a button that would otherwise be inherited from the domain
  default — a per-button opt-out without re-declaring the entire submit
  block.

  See `MishkaGervaz.Form.Entities.Submit` for the parent entity and
  `MishkaGervaz.Form.Dsl.Submit` for the DSL definition.
  """

  alias MishkaGervaz.Form.Entities.Schema

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          active: boolean() | (map() -> boolean()),
          disabled: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          visible: boolean() | (map() -> boolean()),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            active: true,
            disabled: false,
            restricted: false,
            visible: true,
            __spark_metadata__: nil

  @opt_schema [
                label: [
                  type: {:or, [:string, {:fun, 0}]},
                  doc: "Button label. String or zero-arity function."
                ],
                active: [
                  type: {:or, [:boolean, {:fun, 1}]},
                  default: true,
                  doc:
                    "Whether the button is active. Boolean or `fn state -> boolean end`. " <>
                      "Set to `false` to suppress a button inherited from the domain. Resource-only."
                ],
                disabled: [
                  type: {:or, [:boolean, {:fun, 1}]},
                  default: false,
                  doc: "Disable button. Boolean or `fn state -> boolean end`."
                ]
              ] ++ Schema.access_predicates()

  @doc false
  def opt_schema, do: @opt_schema

  def transform(button), do: {:ok, button}
end

defmodule MishkaGervaz.Form.Entities.Submit do
  @moduledoc """
  Submit / cancel button block — the singleton entity that owns the
  three button sub-entities (`create`, `update`, `cancel`), the `ui`
  styling sub-entity, and the `position` field (`:top`, `:bottom`, or
  `:both`).

  When no `submit` block is declared on a resource, all three buttons
  fall back to the domain defaults (see
  `MishkaGervaz.Form.Dsl.DomainDefaults`). When a `submit` block exists
  but defines no buttons, no buttons render — declaring an empty submit
  is a deliberate "render nothing" signal. Partial blocks inherit
  per-button: missing buttons fall back to the domain, present ones
  override.

  ## Example

      submit do
        create label: "Create Post"
        update label: "Save Post"
        cancel label: "Discard"
        position :bottom

        ui do
          submit_class "bg-blue-600 text-white"
          cancel_class "bg-gray-200"
          wrapper_class "flex gap-4"
        end
      end

  See `MishkaGervaz.Form.Dsl.Submit` for the DSL entity declaration,
  `MishkaGervaz.Form.Entities.Submit.Button` for per-button options,
  and `MishkaGervaz.Form.Entities.Submit.Ui` for shared button styling.
  """

  alias __MODULE__.Button
  alias MishkaGervaz.Helpers

  @type t :: %__MODULE__{
          create: Button.t() | nil,
          update: Button.t() | nil,
          cancel: Button.t() | nil,
          position: :top | :bottom | :both,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct create: nil,
            update: nil,
            cancel: nil,
            position: :bottom,
            ui: nil,
            __spark_metadata__: nil

  @opt_schema [
    position: [
      type: {:in, [:top, :bottom, :both]},
      default: :bottom,
      doc: "Button position."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the submit after DSL compilation.

  Extracts nested entities from list wrappers.
  """
  def transform(%__MODULE__{} = submit) do
    {:ok,
     submit
     |> Helpers.extract_singleton_entity(:ui)
     |> Helpers.extract_singleton_entity(:create)
     |> Helpers.extract_singleton_entity(:update)
     |> Helpers.extract_singleton_entity(:cancel)}
  end

  def transform(submit), do: {:ok, submit}
end

defmodule MishkaGervaz.Form.Entities.Submit.Ui do
  @moduledoc """
  Shared button styling for a `MishkaGervaz.Form.Entities.Submit`
  block — submit-button class, cancel-button class, and the wrapper
  container class.
  """

  @type t :: %__MODULE__{
          submit_class: String.t() | nil,
          cancel_class: String.t() | nil,
          wrapper_class: String.t() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct submit_class: nil,
            cancel_class: nil,
            wrapper_class: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    submit_class: [
      type: :string,
      doc: "Submit button CSS classes."
    ],
    cancel_class: [
      type: :string,
      doc: "Cancel button CSS classes."
    ],
    wrapper_class: [
      type: :string,
      doc: "Button wrapper CSS classes."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end

defmodule MishkaGervaz.Form.Entities.Submit.Button do
  @moduledoc """
  Entity struct for a single submit/cancel button configuration.

  Each button (create, update, cancel) is an independent entity with its own
  `label`, `active`, `disabled`, `restricted`, and `visible` options.

  The `active` option is intended for resources only — it suppresses a button
  that would otherwise be inherited from the domain. Use `active: false` to
  opt out of a domain-defined button on a per-resource basis.
  """

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
    ],
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Master-only visibility. Boolean or `fn state -> boolean end`."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Button visibility. Boolean or `fn state -> boolean end`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(button), do: {:ok, button}
end

defmodule MishkaGervaz.Form.Entities.Submit do
  @moduledoc """
  Entity struct for form submit button configuration.

  This module defines the struct and schema for submit buttons, following Ash's
  entity pattern with `opt_schema` and `transform/1`.

  Each button (create, update, cancel) is an independent entity. If no `submit`
  block is defined, all 3 buttons render with domain/fallback defaults. If a
  `submit` block exists but no buttons are defined inside it, no buttons render.
  """

  alias __MODULE__.Button

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
     |> extract_singleton(:ui)
     |> extract_singleton(:create)
     |> extract_singleton(:update)
     |> extract_singleton(:cancel)}
  end

  def transform(submit), do: {:ok, submit}

  defp extract_singleton(submit, key) do
    case Map.get(submit, key) do
      [value | _] -> Map.put(submit, key, value)
      [] -> Map.put(submit, key, nil)
      value when is_struct(value) -> submit
      _ -> submit
    end
  end
end

defmodule MishkaGervaz.Form.Entities.Submit.Ui do
  @moduledoc """
  UI configuration for form submit buttons.
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

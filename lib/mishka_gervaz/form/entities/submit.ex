defmodule MishkaGervaz.Form.Entities.Submit do
  @moduledoc """
  Entity struct for form submit button configuration.

  This module defines the struct and schema for submit buttons, following Ash's
  entity pattern with `opt_schema` and `transform/1`.
  """

  @type t :: %__MODULE__{
          create_label: String.t() | (-> String.t()),
          update_label: String.t() | (-> String.t()),
          cancel_label: String.t() | (-> String.t()),
          show_cancel: boolean(),
          position: :top | :bottom | :both,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct create_label: "Create",
            update_label: "Update",
            cancel_label: "Cancel",
            show_cancel: true,
            position: :bottom,
            ui: nil,
            __spark_metadata__: nil

  @opt_schema [
    create_label: [
      type: {:or, [:string, {:fun, 0}]},
      default: "Create",
      doc: "Submit button label for create."
    ],
    update_label: [
      type: {:or, [:string, {:fun, 0}]},
      default: "Update",
      doc: "Submit button label for update."
    ],
    cancel_label: [
      type: {:or, [:string, {:fun, 0}]},
      default: "Cancel",
      doc: "Cancel button label."
    ],
    show_cancel: [
      type: :boolean,
      default: true,
      doc: "Show cancel button."
    ],
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

  Extracts the nested ui entity from the list wrapper.
  """
  def transform(%__MODULE__{} = submit) do
    {:ok, extract_ui(submit)}
  end

  def transform(submit), do: {:ok, submit}

  defp extract_ui(%{ui: [ui | _]} = submit), do: %{submit | ui: ui}
  defp extract_ui(%{ui: ui} = submit) when is_struct(ui), do: submit
  defp extract_ui(submit), do: submit
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

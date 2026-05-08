defmodule MishkaGervaz.Form.Entities.Header do
  @moduledoc """
  Form header — static title + description pair rendered above the
  fields, with optional icon and a custom HEEx render escape hatch.

  Visibility gating (`visible` / `restricted`) follows the same access
  conventions used by `MishkaGervaz.Form.Entities.Field` and
  `MishkaGervaz.Form.Entities.Group`. Title and description accept
  strings or zero-/one-arity functions, so they can render dynamic
  content from the form state.

  ## Example

      layout do
        header do
          title "Account Permissions"
          description "Configure what this account can access."
          icon "hero-shield-check"
          class "mb-6"
          visible fn state -> state.mode == :update end
        end
      end

  See `MishkaGervaz.Form.Dsl.Layout` for the surrounding section.
  """

  alias MishkaGervaz.Form.Entities.Schema

  @type t :: %__MODULE__{
          title: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          description: String.t() | (-> String.t()) | (map() -> String.t()) | nil,
          icon: String.t() | nil,
          class: String.t() | nil,
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          render:
            (map() -> Phoenix.LiveView.Rendered.t())
            | (map(), map() -> Phoenix.LiveView.Rendered.t())
            | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct title: nil,
            description: nil,
            icon: nil,
            class: nil,
            visible: true,
            restricted: false,
            render: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
                title: [
                  type: {:or, [:string, {:fun, 0}, {:fun, 1}]},
                  doc: "Header title. String, `fn -> _ end`, or `fn state -> _ end`."
                ],
                description: [
                  type: {:or, [:string, {:fun, 0}, {:fun, 1}]},
                  doc: "Header description. String, `fn -> _ end`, or `fn state -> _ end`."
                ],
                icon: [
                  type: :string,
                  doc: "Heroicon name (e.g., \"hero-shield-check\")."
                ],
                class: [
                  type: :string,
                  doc: "CSS classes for the header wrapper."
                ],
                render: [
                  type: {:or, [{:fun, 1}, {:fun, 2}]},
                  doc:
                    "Custom HEEx render. `fn assigns -> ~H\"...\" end` or `fn assigns, state -> ~H\"...\" end`."
                ],
                extra: [
                  type: :map,
                  default: %{},
                  doc: "Additional template-specific options."
                ]
              ] ++ Schema.access_predicates()

  @doc false
  def opt_schema, do: @opt_schema

  def transform(header), do: {:ok, header}
end

defmodule MishkaGervaz.Table.Entities.Header do
  @moduledoc """
  Entity struct for table header configuration.

  The header renders above the table toolbar (filters, bulk actions, etc.).
  Mirrors `MishkaGervaz.Form.Entities.Header` for cross-DSL consistency.

  ## Example

      layout do
        header do
          title "Pages"
          description "All published and draft pages."
          icon "hero-document-text"
          class "mb-6"
          visible true
          restricted false
        end
      end
  """

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
      doc: "Heroicon name (e.g., \"hero-document-text\")."
    ],
    class: [
      type: :string,
      doc: "CSS classes for the header wrapper."
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
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional template-specific options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(header), do: {:ok, header}
end

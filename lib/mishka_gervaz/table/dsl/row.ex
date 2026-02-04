defmodule MishkaGervaz.Table.Dsl.Row do
  @moduledoc """
  Row section DSL definition for table configuration.

  Defines row styling and behavior including click handling and selection.
  """

  alias MishkaGervaz.Table.Entities.RowOverride

  @row_class_schema [
    possible: [
      type: {:list, :string},
      default: [],
      doc: "Possible classes for Tailwind JIT extraction."
    ],
    apply: [
      type: {:fun, 1},
      doc: "Function `fn record -> [class | nil]`."
    ]
  ]

  defp row_class_section do
    %Spark.Dsl.Section{
      name: :class,
      describe: "Row class configuration for dynamic styling.",
      schema: @row_class_schema
    }
  end

  defp row_override_entity do
    %Spark.Dsl.Entity{
      name: :override,
      describe: "Row override configuration for custom rendering.",
      target: RowOverride,
      schema: RowOverride.opt_schema(),
      transform: {RowOverride, :transform, []}
    }
  end

  @row_schema [
    event: [
      type: :string,
      doc: "Event name triggered on row click."
    ],
    payload: [
      type: {:or, [{:fun, 1}, :map]},
      doc: "Payload for row click. Map or `fn record -> map`."
    ],
    selectable: [
      type: :boolean,
      default: false,
      doc: "Enable row selection checkboxes."
    ]
  ]

  @doc false
  def schema, do: @row_schema

  @doc """
  Returns the row section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :row,
      describe: "Row styling and behavior.",
      schema: @row_schema,
      sections: [row_class_section()],
      entities: [row_override_entity()]
    }
  end
end

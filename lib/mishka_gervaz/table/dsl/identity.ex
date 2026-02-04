defmodule MishkaGervaz.Table.Dsl.Identity do
  @moduledoc """
  Identity section DSL definition for table configuration.

  Defines naming and routing configuration for the table.
  """

  @schema [
    name: [
      type: :atom,
      required: true,
      doc: "Unique table identifier."
    ],
    route: [
      type: :string,
      required: true,
      doc: "Base route for links (used in row actions)."
    ],
    stream_name: [
      type: :atom,
      doc: "Phoenix stream name. Auto-generated if not set."
    ]
  ]

  @doc false
  def schema, do: @schema

  @doc """
  Returns the identity section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :identity,
      describe: "Naming and routing configuration for the table.",
      schema: @schema
    }
  end
end

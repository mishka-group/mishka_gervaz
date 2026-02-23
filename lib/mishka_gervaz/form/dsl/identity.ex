defmodule MishkaGervaz.Form.Dsl.Identity do
  @moduledoc """
  Identity section DSL definition for form configuration.

  Defines naming and routing configuration for the form.
  """

  @schema [
    name: [
      type: :atom,
      required: true,
      doc: "Unique form identifier."
    ],
    route: [
      type: :string,
      doc: "Base route for redirects after save."
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
      describe: "Naming and routing configuration for the form.",
      schema: @schema
    }
  end
end

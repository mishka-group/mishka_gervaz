defmodule MishkaGervaz.Form.Dsl.Identity do
  @moduledoc """
  Identity section — naming and routing for a form.

  Every form must declare an identity. `name` is required and is used as
  the LiveComponent id and as the lookup key for `Info.Form` accessors;
  `route` powers post-save redirects; `stream_name` defaults to a value
  derived from `name` when omitted.

  ## Example

      identity do
        name :form_post
        route "/admin/posts"
        stream_name :form_post_stream
      end
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

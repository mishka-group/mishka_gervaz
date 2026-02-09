defmodule MishkaGervaz.Form.Dsl.Hooks do
  @moduledoc """
  Hooks section DSL definition for form configuration.

  Defines lifecycle callbacks for form events.

  ## Example

      hooks do
        before_save fn params, state ->
          # Transform params before saving
          Map.put(params, "processed", true)
        end

        after_save fn result, state ->
          # Side effects after save
          Logger.info("Saved: \#{inspect(result)}")
          state
        end
      end
  """

  @hooks_schema [
    on_init: [
      type: {:fun, 2},
      doc: "`fn form, state -> form` - After form initialization."
    ],
    before_save: [
      type: {:fun, 2},
      doc:
        "`fn params, state -> params | {:halt, state}` - Before save. Return {:halt, state} to cancel."
    ],
    after_save: [
      type: {:fun, 2},
      doc: "`fn result, state -> state` - After successful save."
    ],
    on_error: [
      type: {:fun, 2},
      doc: "`fn form, state -> state` - On save error."
    ],
    on_cancel: [
      type: {:fun, 1},
      doc: "`fn state -> state` - When form is cancelled."
    ],
    on_validate: [
      type: {:fun, 2},
      doc: "`fn params, state -> params` - On form validate event."
    ],
    on_change: [
      type: {:fun, 3},
      doc: "`fn field, value, state -> state | {:halt, state}` - On individual field change."
    ],
    transform_params: [
      type: {:fun, 1},
      doc: "`fn params -> params` - Transform params before action."
    ],
    transform_errors: [
      type: {:fun, 2},
      doc: "`fn changeset, errors -> errors` - Transform error messages."
    ]
  ]

  @doc false
  def schema, do: @hooks_schema

  @doc """
  Returns the hooks section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :hooks,
      describe: "Lifecycle callbacks for forms.",
      schema: @hooks_schema
    }
  end
end

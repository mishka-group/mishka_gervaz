defmodule MishkaGervaz.Form.Dsl.Hooks do
  @moduledoc """
  Hooks section DSL definition for form configuration.

  Defines lifecycle callbacks for form events.

  ## Example

      hooks do
        before_save fn %{"form" => values} = params, _state ->
          Map.put(params, "form", Map.put(values, "processed", true))
        end

        after_save fn record, _state ->
          Logger.info("Saved: \#{inspect(record)}")
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
        "`fn params, state -> params | {:cont, params} | {:halt, reason}` - Before save. `params` are the save event's params, the form's values under `\"form\"`; the params returned, bare or in `{:cont, params}`, are saved, and `{:halt, reason}` cancels the save."
    ],
    after_save: [
      type: {:fun, 2},
      doc:
        "`fn record, state -> any` - After a successful save, with the saved record, for side effects. What it returns is not read: the form then starts over."
    ],
    on_error: [
      type: {:fun, 2},
      doc:
        "`fn form, state -> state` - After a failed save, with the form it left. The state it returns is the one the form shows; anything else keeps the form's own."
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
    ]
  ]

  @js_hooks_schema [
    on_init: [
      type: {:fun, 0},
      doc: "`fn -> %JS{}` - JS commands for phx-mounted on form container."
    ],
    after_save: [
      type: {:fun, 1},
      doc:
        "`fn record_id -> %JS{}` - JS commands after successful save. Receives saved record ID."
    ],
    on_cancel: [
      type: {:fun, 1},
      doc:
        "`fn record_id -> %JS{}` - JS commands when form is cancelled. Receives record ID or nil (create)."
    ],
    on_error: [
      type: {:fun, 1},
      doc:
        "`fn record_id -> %JS{}` - JS commands on save error. Receives record ID or nil (create)."
    ]
  ]

  @doc false
  def schema, do: @hooks_schema

  @doc false
  def js_schema, do: @js_hooks_schema

  @doc """
  Returns the hooks section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :hooks,
      describe: "Lifecycle callbacks for forms.",
      schema: @hooks_schema,
      sections: [js_section()]
    }
  end

  defp js_section do
    %Spark.Dsl.Section{
      name: :js,
      describe: "Client-side JS commands for form lifecycle events.",
      schema: @js_hooks_schema
    }
  end
end

defmodule MishkaGervaz.Table.Dsl.Hooks do
  @moduledoc """
  Hooks section DSL definition for table configuration.

  Defines lifecycle callbacks for table events.

  ## Return Values

  Most hooks can return:
  - `socket` - Continue with modified socket
  - `{:cont, socket}` - Explicitly continue with modified socket
  - `{:halt, socket}` - Stop the action (e.g., skip realtime update, cancel expand)

  ## Example

      hooks do
        on_realtime fn notification, socket ->
          # Skip updates for records created by current user
          if notification.data.created_by_id == socket.assigns.current_user.id do
            {:halt, socket}
          else
            {:cont, put_flash(socket, :info, "New record added!")}
          end
        end

        on_filter fn filter_values, socket ->
          # Log filter changes
          Logger.info("Filters changed: \#{inspect(filter_values)}")
          socket
        end
      end
  """

  @hooks_schema [
    on_load: [
      type: {:fun, 2},
      doc: "`fn query, state -> {:cont, query} | query` - Before data loaded. Modify query."
    ],
    before_delete: [
      type: {:fun, 2},
      doc: "`fn record, state -> {:ok, state} | {:halt, {:error, msg}}` - Before delete."
    ],
    after_delete: [
      type: {:fun, 2},
      doc: "`fn record, state -> any` - After delete (side effects only)."
    ],
    on_realtime: [
      type: {:fun, 2},
      doc:
        "`fn notification, socket -> socket | {:cont, socket} | {:halt, socket}` - PubSub received. Return {:halt, socket} to skip update."
    ],
    on_expand: [
      type: {:fun, 2},
      doc:
        "`fn record_id, socket -> socket | {:cont, socket} | {:halt, socket}` - Row expanded. Return {:halt, socket} to cancel."
    ],
    on_filter: [
      type: {:fun, 2},
      doc:
        "`fn filter_values, socket -> socket | {:cont, socket} | {:halt, socket}` - Filter changed."
    ],
    on_event: [
      type: {:fun, 3},
      doc:
        "`fn event_name, params, socket -> {:ok, socket} | {:halt, socket}` - Custom event handler."
    ],
    on_select: [
      type: {:fun, 2},
      doc:
        "`fn selected_ids, socket -> socket | {:cont, socket} | {:halt, socket}` - Selection changed."
    ],
    on_sort: [
      type: {:fun, 2},
      doc:
        "`fn {field, direction}, socket -> socket | {:cont, socket} | {:halt, socket}` - Sort changed."
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
      describe: "Lifecycle callbacks.",
      schema: @hooks_schema
    }
  end
end

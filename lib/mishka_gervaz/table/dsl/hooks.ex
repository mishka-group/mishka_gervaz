defmodule MishkaGervaz.Table.Dsl.Hooks do
  @moduledoc """
  Hooks section DSL definition for table configuration.

  Defines lifecycle callbacks for table events.

  ## Three layers

  1. **Global lifecycle** — fires for every event of a kind (`before_delete`,
     `after_delete`, `on_realtime`, `on_filter`, …). These keep their existing
     behavior.

  2. **Per-action observers** — fire alongside the built-in handler for a
     specific row or bulk action, keyed by the action's `name`. They cannot
     replace the handler; they observe and decorate it.

       - `before_row_action :name, fn record, state -> ... end`
       - `after_row_action  :name, fn result, state -> ... end`
       - `on_row_action_success :name, fn result, state -> socket end`
       - `on_row_action_error   :name, fn reason, state -> socket end`
       - `before_bulk_action :name, fn ids, state -> ... end`
       - `after_bulk_action  :name, fn result, state -> ... end`
       - `on_bulk_action_success :name, fn result, state -> socket end`
       - `on_bulk_action_error   :name, fn errors, state -> socket end`

     A list of action names is also accepted to share one hook across actions:
     `before_row_action [:unarchive, :restore], fn ... end`.

  3. **Full overrides** — replace the built-in handler entirely. These are the
     same runtime as the legacy `{:on_event, name}` / `{:on_bulk_action, name}`
     keys; the DSL aliases below are the documented form.

       - `override_row_action  :name, fn payload, state -> {:ok, state} end`
       - `override_bulk_action :name, fn ids, state -> {:ok, state} end`

  4. **Built-in state-transition rules** — opt-in flags for common UX
     transitions, declared directly inside `hooks do … end`:

       hooks do
         switch_to_active_on_empty_archive true
         clear_selection_after_bulk true
         reset_page_on_empty_current_page true
         redirect_on_empty "/dashboard"
       end

  ## Return Values

  Most hooks can return:
  - `socket` - Continue with modified socket
  - `{:cont, socket}` - Explicitly continue with modified socket
  - `{:halt, socket}` - Stop the action (e.g., skip realtime update, cancel expand)

  ## Example

      hooks do
        on_realtime fn notification, socket ->
          if notification.data.created_by_id == socket.assigns.current_user.id do
            {:halt, socket}
          else
            {:cont, put_flash(socket, :info, "New record added!")}
          end
        end

        before_row_action :unarchive, fn record, state ->
          if record.locked?, do: {:halt, {:error, "locked"}}, else: :ok
        end

        after_bulk_action :unarchive, fn _result, _state -> :ok end

        switch_to_active_on_empty_archive true
      end
  """

  alias MishkaGervaz.Table.Entities.ActionHook

  @global_hooks_schema [
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

  @builtins_schema [
    switch_to_active_on_empty_archive: [
      type: :boolean,
      default: false,
      doc:
        "Switch to active mode after a successful unarchive/permanent_destroy if the archive list is now empty."
    ],
    switch_to_archive_on_empty_active: [
      type: :boolean,
      default: false,
      doc:
        "Symmetric: switch to archive mode after a successful destroy if the active list is now empty."
    ],
    clear_selection_after_bulk: [
      type: :boolean,
      default: true,
      doc: "Clear `selected_ids` / `excluded_ids` / `select_all?` after a successful bulk action."
    ],
    reset_page_on_empty_current_page: [
      type: :boolean,
      default: false,
      doc: "Reload page 1 if the current page becomes empty after an action."
    ],
    redirect_on_empty: [
      type: {:or, [:string, {:fun, 1}]},
      doc:
        "Redirect path (string or `fn state -> path end`) when `total_count == 0` after a load."
    ]
  ]

  @hooks_schema @global_hooks_schema ++ @builtins_schema

  @hook_phases [
    :before_row_action,
    :after_row_action,
    :on_row_action_success,
    :on_row_action_error,
    :before_bulk_action,
    :after_bulk_action,
    :on_bulk_action_success,
    :on_bulk_action_error,
    :override_row_action,
    :override_bulk_action
  ]

  @doc false
  def schema, do: @hooks_schema

  @doc false
  def builtins_schema, do: @builtins_schema

  @doc false
  def hook_phases, do: @hook_phases

  defp action_hook_entity(name) do
    %Spark.Dsl.Entity{
      name: name,
      describe:
        "Per-action #{name |> Atom.to_string() |> String.replace("_", " ")} hook. First arg: action name atom or list of atoms. Second arg: function.",
      target: ActionHook,
      args: [:names, :run],
      schema: ActionHook.opt_schema(),
      auto_set_fields: [phase: name],
      transform: {ActionHook, :transform, []}
    }
  end

  @doc """
  Returns the hooks section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :hooks,
      describe: "Lifecycle callbacks.",
      schema: @hooks_schema,
      entities: Enum.map(@hook_phases, &action_hook_entity/1)
    }
  end
end

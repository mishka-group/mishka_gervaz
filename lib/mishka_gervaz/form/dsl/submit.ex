defmodule MishkaGervaz.Form.Dsl.Submit do
  @moduledoc """
  Submit entity — configures the create / update / cancel / discard buttons.

  The `submit` block is a singleton composed of three button
  sub-entities (`create`, `update`, `cancel`), an optional `ui`
  sub-entity for shared button styling, and a `position` field
  (`:top` or `:bottom`). Each button supports inline keyword form for
  static options and full block form when you need function-based
  predicates (`disabled` / `restricted` / `visible`).

  ## Example — populated buttons

      submit do
        create label: "Create Post"
        update label: "Save Post"
        cancel label: "Discard"
        position :bottom

        ui do
          submit_class "bg-blue-600 text-white"
          cancel_class "bg-gray-200"
          wrapper_class "flex gap-4"
        end
      end

  ## Example — function-based predicates (block form)

      submit do
        create label: "Create Item", restricted: true

        update do
          label "Save Item"
          disabled fn _state -> false end
          restricted fn _state -> false end
          visible fn _state -> true end
        end

        cancel label: "Go Back", visible: false
        position :top
      end

  ## Discard

  `discard` draws a button beside Save, shown while the form holds changes (`state.dirty?`), that
  puts the form back to its starting values: an edit reads its record again, a create starts over
  empty with its `defaults`. A `:tabs` form stays on the tab it is on. Without a `discard` block
  there is no such button.

      submit do
        discard label: "Discard"
      end

  ## Inheritance

  Resources without a `submit` block inherit the entire submit map from
  the domain (see `MishkaGervaz.Form.Dsl.DomainDefaults`). Resources
  with a partial block inherit per-button: missing buttons fall back to
  the domain's, present buttons override them.

  See `MishkaGervaz.Form.Entities.Submit` and
  `MishkaGervaz.Form.Entities.Submit.Button` for the full option list.
  """

  alias MishkaGervaz.Form.Entities.Submit

  defp submit_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI configuration for submit buttons.",
      target: Submit.Ui,
      schema: Submit.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Submit.Ui, :transform, []}
    }
  end

  defp button_entity(name) do
    %Spark.Dsl.Entity{
      name: name,
      describe: "#{name} button configuration.",
      target: Submit.Button,
      schema: Submit.Button.opt_schema(),
      singleton_entity_keys: [name],
      transform: {Submit.Button, :transform, []}
    }
  end

  @doc """
  Returns the submit entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :submit,
      describe: "Submit and cancel button configuration.",
      target: Submit,
      schema: Submit.opt_schema(),
      singleton_entity_keys: [:submit],
      entities: [
        create: [button_entity(:create)],
        update: [button_entity(:update)],
        cancel: [button_entity(:cancel)],
        discard: [button_entity(:discard)],
        ui: [submit_ui_entity()]
      ],
      transform: {Submit, :transform, []}
    }
  end
end

defmodule MishkaGervaz.Form.Dsl.Submit do
  @moduledoc """
  Submit entity DSL definition for form configuration.

  Defines the submit/cancel button configuration as a singleton entity
  with per-button sub-entities (create, update, cancel).
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
        ui: [submit_ui_entity()]
      ],
      transform: {Submit, :transform, []}
    }
  end
end

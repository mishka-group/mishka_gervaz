defmodule MishkaGervaz.Form.Dsl.Submit do
  @moduledoc """
  Submit entity DSL definition for form configuration.

  Defines the submit/cancel button configuration as a singleton entity.
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
      entities: [ui: [submit_ui_entity()]],
      transform: {Submit, :transform, []}
    }
  end
end

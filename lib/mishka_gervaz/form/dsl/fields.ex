defmodule MishkaGervaz.Form.Dsl.Fields do
  @moduledoc """
  Fields section DSL definition for form configuration.

  Defines form fields with support for manual fields and auto-discovery.
  """

  alias MishkaGervaz.Form.Entities.Field
  alias MishkaGervaz.Form.Entities.NestedField
  alias MishkaGervaz.Form.Entities.AutoFields

  defp field_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for the field.",
      target: Field.Ui,
      schema: Field.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {Field.Ui, :transform, []}
    }
  end

  defp field_preload_entity do
    %Spark.Dsl.Entity{
      name: :preload,
      describe: "Three-tier preload configuration for relation fields.",
      target: Field.Preload,
      schema: Field.Preload.opt_schema(),
      singleton_entity_keys: [:preload],
      transform: {Field.Preload, :transform, []}
    }
  end

  defp nested_field_ui_entity do
    %Spark.Dsl.Entity{
      name: :ui,
      describe: "UI/presentation configuration for the nested sub-field.",
      target: NestedField.Ui,
      schema: NestedField.Ui.opt_schema(),
      singleton_entity_keys: [:ui],
      transform: {NestedField.Ui, :transform, []}
    }
  end

  defp nested_field_entity do
    %Spark.Dsl.Entity{
      name: :nested_field,
      describe: "Define a sub-field within a nested/embedded form field.",
      target: NestedField,
      args: [:name, :type],
      identifier: :name,
      schema: NestedField.opt_schema(),
      entities: [
        ui: [nested_field_ui_entity()]
      ],
      transform: {NestedField, :transform, []}
    }
  end

  defp field_entity do
    %Spark.Dsl.Entity{
      name: :field,
      describe: "Define a form field.",
      target: Field,
      args: [:name, :type],
      identifier: :name,
      schema: Field.opt_schema(),
      entities: [
        ui: [field_ui_entity()],
        preload: [field_preload_entity()],
        _nested_field_entities: [nested_field_entity()]
      ],
      transform: {Field, :transform, []}
    }
  end

  defp auto_fields_defaults_entity do
    %Spark.Dsl.Entity{
      name: :defaults,
      describe: "Default options for auto-discovered fields.",
      target: AutoFields.Defaults,
      schema: AutoFields.Defaults.opt_schema(),
      singleton_entity_keys: [:defaults],
      transform: {AutoFields.Defaults, :transform, []}
    }
  end

  defp auto_fields_ui_defaults_entity do
    %Spark.Dsl.Entity{
      name: :ui_defaults,
      describe: "Default UI options for auto-discovered fields.",
      target: AutoFields.UiDefaults,
      schema: AutoFields.UiDefaults.opt_schema(),
      singleton_entity_keys: [:ui_defaults],
      transform: {AutoFields.UiDefaults, :transform, []}
    }
  end

  defp auto_fields_override_entity do
    %Spark.Dsl.Entity{
      name: :override,
      describe: "Override a specific auto-discovered field.",
      target: AutoFields.Override,
      args: [:name],
      schema: AutoFields.Override.opt_schema(),
      entities: [ui: [field_ui_entity()]],
      transform: {AutoFields.Override, :transform, []}
    }
  end

  defp auto_fields_entity do
    %Spark.Dsl.Entity{
      name: :auto_fields,
      describe: "Auto-discover fields from Ash resource attributes.",
      target: AutoFields,
      schema: AutoFields.opt_schema(),
      entities: [
        defaults: [auto_fields_defaults_entity()],
        ui_defaults: [auto_fields_ui_defaults_entity()],
        overrides: [auto_fields_override_entity()]
      ],
      transform: {AutoFields, :transform, []}
    }
  end

  @section_schema [
    field_order: [
      type: {:list, :atom},
      doc: "Field display order. Fields not in list appear at end."
    ]
  ]

  @doc false
  def schema, do: @section_schema

  @doc """
  Returns the fields section definition.
  """
  def section do
    %Spark.Dsl.Section{
      name: :fields,
      describe: "Define form fields.",
      schema: @section_schema,
      entities: [field_entity(), auto_fields_entity()]
    }
  end
end

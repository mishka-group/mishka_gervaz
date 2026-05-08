defmodule MishkaGervaz.Form.Dsl.Fields do
  @moduledoc """
  Fields section — declares form fields manually or via auto-discovery.

  Two top-level entities live here:

    * `field :name, :type do … end` — explicit field with full control.
    * `auto_fields do … end` — discover fields from the resource's
      public Ash attributes, with `override` for per-field tweaks.

  The `field_order` schema key sets display order; fields not listed
  appear at the end in declaration order.

  ## Example — explicit fields

      fields do
        field :title, :text do
          required true
          position :first

          ui do
            label "Post Title"
            placeholder "Enter title..."
            span 2
          end
        end

        field :status, :select do
          required true
          default :draft
          options [{:draft, "Draft"}, {:published, "Published"}]
        end

        field :user_id, :relation do
          load_action {:master_read, :tenant_read}
          mode :search
          display_field :email
        end
      end

  ## Example — auto-discovery

      fields do
        auto_fields do
          except [:id, :internal_only]
          position :end

          defaults required: false, visible: true

          override :age, type: :range, required: true

          override :bio do
            ui do
              label "Biography"
              rows 8
            end
          end
        end
      end

  ## Field types

  Built-in types live under `MishkaGervaz.Form.Types.Field.*` —
  `:text`, `:textarea`, `:select`, `:multi_select`, `:combobox`,
  `:relation`, `:nested`, `:upload`, `:toggle`, `:checkbox`, `:date`,
  `:datetime`, `:number`, `:json`, `:string_list`, `:password`, `:range`.
  When `type` is omitted, it is inferred from the matching Ash
  attribute.

  ## Nested fields

  For `:nested` fields (embedded resources or constrained `{:array, :map}`
  attributes), declare per-sub-field overrides with
  `nested_field :name do … end` inside the parent field. See
  `MishkaGervaz.Form.Entities.NestedField`.
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

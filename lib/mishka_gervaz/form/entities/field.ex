defmodule MishkaGervaz.Form.Entities.Field do
  @moduledoc """
  Form field — name, type, validation, access predicates, and an
  optional `ui` sub-entity for label / placeholder / styling plus an
  optional `preload` sub-entity for relation field eager-loading.

  Field type is either a built-in token (`:text`, `:textarea`, `:select`,
  `:relation`, `:nested`, etc.) or a module implementing
  `MishkaGervaz.Form.Behaviours.FieldType`. When omitted, type is
  inferred from the matching Ash attribute. Visibility (`visible` /
  `restricted`) follows the standard predicate convention shared with
  groups, headers, footers, and notices.

  ## Example

      fields do
        field :title, :text do
          required true
          position :first

          ui do
            label "Title"
            placeholder "Enter title..."
            span 2
          end
        end

        field :user_id, :relation do
          mode :search
          display_field :email
          search_field :email

          preload do
            always [:role]
          end
        end
      end

  See `MishkaGervaz.Form.Dsl.Fields` for the surrounding section,
  `MishkaGervaz.Form.Entities.Field.Ui` for the `ui` sub-entity,
  `MishkaGervaz.Form.Entities.Field.Preload` for the `preload`
  sub-entity, `MishkaGervaz.Form.Entities.NestedField` for sub-field
  declarations inside a `:nested` field, and
  `MishkaGervaz.Form.Behaviours.FieldType` for custom field types.
  """

  alias MishkaGervaz.Form.Entities.Schema
  alias MishkaGervaz.Helpers

  @type position :: integer() | :first | :last | {:before, atom()} | {:after, atom()}

  @type t :: %__MODULE__{
          name: atom(),
          type: atom() | module(),
          source: atom() | nil,
          required: boolean(),
          visible: boolean() | (map() -> boolean()),
          show_on: :create | :update | nil,
          restricted: boolean() | (map() -> boolean()),
          default: any(),
          depends_on: atom() | nil,
          virtual: boolean(),
          resource: module() | nil,
          derive_value: (struct() -> any()) | nil,
          options: list() | (-> list()) | nil,
          options_source: {module(), atom(), atom()} | nil,
          display_field:
            atom()
            | (struct() -> String.t())
            | (struct(), map() -> String.t())
            | nil,
          search_field: atom() | nil,
          value_field: atom() | nil,
          readonly: boolean() | (map() -> boolean()),
          mode: :static | :load_more | :search | :search_multi,
          page_size: pos_integer(),
          load_action: atom() | {atom(), atom()} | nil,
          load: (any(), map() -> any()) | nil,
          apply: (any(), any(), map() -> any()) | nil,
          format: (any() -> any()) | (map(), map(), any() -> any()) | nil,
          render:
            (struct() -> Phoenix.LiveView.Rendered.t())
            | (struct(), map() -> Phoenix.LiveView.Rendered.t())
            | nil,
          position: position() | nil,
          include_nil: boolean() | String.t() | (-> String.t()),
          min: integer() | nil,
          max: integer() | nil,
          min_chars: integer() | nil,
          auto_fields: boolean(),
          nested_fields: list(),
          array_fields: list(),
          add_label: String.t() | nil,
          remove_label: String.t() | nil,
          ui: __MODULE__.Ui.t() | nil,
          preload: __MODULE__.Preload.t() | nil,
          type_module: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    :source,
    type: nil,
    required: false,
    visible: true,
    show_on: nil,
    restricted: false,
    default: nil,
    depends_on: nil,
    virtual: false,
    resource: nil,
    derive_value: nil,
    options: nil,
    options_source: nil,
    display_field: nil,
    search_field: nil,
    value_field: nil,
    readonly: false,
    mode: :static,
    page_size: 20,
    load_action: nil,
    load: nil,
    apply: nil,
    format: nil,
    render: nil,
    position: nil,
    include_nil: false,
    min: nil,
    max: nil,
    min_chars: nil,
    auto_fields: false,
    nested_fields: [],
    _nested_field_entities: [],
    array_fields: [],
    add_label: nil,
    remove_label: nil,
    ui: nil,
    preload: nil,
    type_module: nil,
    __spark_metadata__: nil
  ]

  @builtin_field_types [
    :text,
    :password,
    :textarea,
    :number,
    :checkbox,
    :date,
    :datetime,
    :select,
    :multi_select,
    :relation,
    :json,
    :nested,
    :array_of_maps,
    :string_list,
    :file,
    :hidden,
    :toggle,
    :range,
    :upload,
    :combobox
  ]

  @opt_schema [
                name: [
                  type: :atom,
                  required: true,
                  doc: "Field identifier."
                ],
                type: [
                  type:
                    {:or,
                     [
                       {:in, [nil | @builtin_field_types]},
                       {:behaviour, MishkaGervaz.Form.Behaviours.FieldType}
                     ]},
                  default: nil,
                  doc:
                    "Field type. Built-in atom, custom module implementing FieldType behaviour, or nil for auto-detection from Ash attribute."
                ],
                source: [
                  type: :atom,
                  doc: "Data source attribute. Defaults to field name."
                ],
                required: [
                  type: :boolean,
                  default: false,
                  doc: "Whether the field is required."
                ],
                show_on: [
                  type: {:in, [:create, :update]},
                  doc: "Only show on specific action mode."
                ],
                default: [
                  type: :any,
                  doc: "Default value for the field."
                ],
                depends_on: [
                  type: :atom,
                  doc: "Field this depends on (for cascading selects)."
                ],
                virtual: [
                  type: :boolean,
                  default: false,
                  doc: "Virtual field (not in resource attributes)."
                ],
                resource: [
                  type: {:behaviour, Ash.Resource},
                  doc: "Resource module for virtual or relation fields."
                ],
                derive_value: [
                  type: {:fun, 1},
                  doc: "Derive value from record on edit. `fn record -> value end`"
                ],
                options: [
                  type: {:or, [{:list, :any}, {:fun, 0}]},
                  doc: "Static options or function returning options."
                ],
                options_source: [
                  type: {:tuple, [{:behaviour, Ash.Resource}, :atom, :atom]},
                  doc: "Options from resource: {resource, action, display_field}."
                ],
                display_field: [
                  type: {:or, [:atom, {:fun, 1}, {:fun, 2}]},
                  doc: "Display field for relation/select options."
                ],
                search_field: [
                  type: :atom,
                  doc: "Field to search on for autocomplete."
                ],
                value_field: [
                  type: :atom,
                  doc:
                    "Attribute to store from selected record instead of :id. For relation fields that need a non-primary-key value."
                ],
                readonly: [
                  type: {:or, [:boolean, {:fun, 1}]},
                  default: false,
                  doc: "Render as read-only. Boolean or `fn state -> boolean end`."
                ],
                mode: [
                  type: {:in, [:static, :load_more, :search, :search_multi]},
                  default: :static,
                  doc: "Data loading mode for select/relation fields."
                ],
                page_size: [
                  type: :pos_integer,
                  default: 20,
                  doc: "Page size for load_more/search modes."
                ],
                load_action: [
                  type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
                  doc:
                    "Action to use for loading options. Atom or `{master_action, tenant_action}` tuple. If the action has pagination, it must set `required?: false`."
                ],
                load: [
                  type: {:fun, 2},
                  doc: "Custom load function. `fn query, state -> results end`"
                ],
                apply: [
                  type: {:fun, 3},
                  doc: "Custom apply function. `fn value, changeset, state -> changeset end`"
                ],
                format: [
                  type: {:or, [{:fun, 1}, {:fun, 3}]},
                  doc: "Value formatter for display."
                ],
                render: [
                  type: {:or, [{:fun, 1}, {:fun, 2}]},
                  doc: "Custom HEEx render function."
                ],
                position: [
                  type: :any,
                  doc:
                    "Field position (integer, :first, :last, {:before, :field}, {:after, :field})."
                ],
                include_nil: [
                  type: {:or, [:boolean, :string, {:fun, 0}]},
                  default: false,
                  doc:
                    "Include nil option in select. String or `fn -> gettext(...) end` sets label."
                ],
                min: [
                  type: :integer,
                  doc: "Minimum value for number/range fields."
                ],
                max: [
                  type: :integer,
                  doc: "Maximum value for number/range fields."
                ],
                min_chars: [
                  type: :integer,
                  doc: "Minimum characters before search triggers."
                ],
                auto_fields: [
                  type: :boolean,
                  default: false,
                  doc:
                    "When true with explicit nested_field entries, auto-detect remaining fields from the resource and merge with overrides."
                ],
                nested_fields: [
                  type: {:list, :any},
                  default: [],
                  doc: "Fields for nested/embedded forms."
                ],
                array_fields: [
                  type: {:list, :any},
                  default: [],
                  doc: "Fields for array_of_maps entries."
                ],
                add_label: [
                  type: {:or, [:string, {:fun, 0}]},
                  doc:
                    "Label for add button in array/nested/string_list fields. String or `fn -> gettext(...) end`."
                ],
                remove_label: [
                  type: {:or, [:string, {:fun, 0}]},
                  doc:
                    "Label for remove button in array/nested/string_list fields. String or `fn -> gettext(...) end`."
                ]
              ] ++ Schema.access_predicates()

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the field after DSL compilation.

  Sets defaults, resolves the type_module, and extracts nested entities.
  """
  def transform(%__MODULE__{} = field) do
    field =
      field
      |> maybe_set_virtual()
      |> Helpers.extract_singleton_entity(:ui)
      |> Helpers.extract_singleton_entity(:preload)
      |> extract_nested_field_entities()
      |> promote_ui_labels()
      |> maybe_set_source()
      |> resolve_type_module()

    {:ok, field}
  end

  def transform(field), do: {:ok, field}

  defp maybe_set_virtual(%{type: :upload} = field), do: %{field | virtual: true}
  defp maybe_set_virtual(field), do: field

  defp extract_nested_field_entities(%{_nested_field_entities: entities} = field)
       when is_list(entities) and entities != [] do
    %{field | nested_fields: entities, _nested_field_entities: []}
  end

  defp extract_nested_field_entities(field), do: field

  defp promote_ui_labels(%{ui: %{add_label: _, remove_label: _} = ui} = field) do
    field
    |> maybe_promote(:add_label, ui.add_label)
    |> maybe_promote(:remove_label, ui.remove_label)
  end

  defp promote_ui_labels(field), do: field

  defp maybe_promote(field, key, ui_val) do
    if ui_val && !Map.get(field, key), do: Map.put(field, key, ui_val), else: field
  end

  defp maybe_set_source(%{source: nil, name: name} = field), do: %{field | source: name}
  defp maybe_set_source(field), do: field

  defp resolve_type_module(%{type: type} = field) when not is_nil(type) do
    type_module = MishkaGervaz.Form.Types.Field.get_or_passthrough(type)
    %{field | type_module: type_module}
  end

  defp resolve_type_module(field), do: field
end

defmodule MishkaGervaz.Form.Entities.Field.Ui do
  @moduledoc """
  UI/presentation configuration for a `MishkaGervaz.Form.Entities.Field`
  — label, placeholder, description, icon, CSS classes, debounce
  override, grid span, plus add/remove labels for repeater controls.

  The `extra` map is the escape hatch for template-specific options
  that don't deserve a first-class schema key.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          placeholder: String.t() | nil,
          description: String.t() | nil,
          icon: String.t() | nil,
          class: String.t() | nil,
          wrapper_class: String.t() | nil,
          debounce: integer() | nil,
          span: pos_integer() | nil,
          rows: integer() | nil,
          step: number() | nil,
          autocomplete: String.t() | nil,
          add_label: String.t() | (-> String.t()) | nil,
          remove_label: String.t() | (-> String.t()) | nil,
          disabled_prompt: String.t() | (-> String.t()) | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            placeholder: nil,
            description: nil,
            icon: nil,
            class: nil,
            wrapper_class: nil,
            debounce: nil,
            span: nil,
            rows: nil,
            step: nil,
            autocomplete: nil,
            add_label: nil,
            remove_label: nil,
            disabled_prompt: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Field label. String or `fn -> gettext(...) end` for i18n."
    ],
    placeholder: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Placeholder text. String or `fn -> gettext(...) end` for i18n."
    ],
    description: [
      type: :string,
      doc: "Help text below the field."
    ],
    icon: [
      type: :string,
      doc: "Icon name (e.g. hero icon)."
    ],
    class: [
      type: :string,
      doc: "Field CSS classes."
    ],
    wrapper_class: [
      type: :string,
      doc: "Wrapper element CSS classes."
    ],
    debounce: [
      type: :integer,
      doc: "Debounce milliseconds for validation."
    ],
    span: [
      type: :pos_integer,
      doc: "Grid column span (1-4)."
    ],
    rows: [
      type: :integer,
      doc: "Number of rows for textarea."
    ],
    step: [
      type: {:or, [:integer, :float]},
      doc: "Step value for number/range fields."
    ],
    autocomplete: [
      type: :string,
      doc: "HTML autocomplete attribute value."
    ],
    add_label: [
      type: {:or, [:string, {:fun, 0}]},
      doc:
        "Label for add button in array/nested/string_list fields. String or `fn -> gettext(...) end`."
    ],
    remove_label: [
      type: {:or, [:string, {:fun, 0}]},
      doc:
        "Label for remove button in array/nested/string_list fields. String or `fn -> gettext(...) end`."
    ],
    disabled_prompt: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Prompt text shown when field is disabled."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional options for the field type."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end

defmodule MishkaGervaz.Form.Entities.Field.Preload do
  @moduledoc """
  Three-tier preload configuration for a relation `Field`.

  Supports separate preload lists for all users (`always`), master
  users (`master`), and tenant users (`tenant`), allowing fine-grained
  control over which relationships are eagerly loaded based on the
  current user's access level. Each list accepts atoms or
  `{source, alias}` tuples — the `:always` list is always read; the
  `:master` and `:tenant` lists are merged in based on
  `state.master_user?`.

  Mirrors the resource-level `MishkaGervaz.Form.Dsl.Source`
  preload block but scoped to a single relation field.
  """

  @preload_item_type {:or, [:atom, {:tuple, [:atom, :atom]}]}

  @type t :: %__MODULE__{
          always: [atom() | {atom(), atom()}],
          master: [atom() | {atom(), atom()}],
          tenant: [atom() | {atom(), atom()}],
          __spark_metadata__: map() | nil
        }

  defstruct always: [],
            master: [],
            tenant: [],
            __spark_metadata__: nil

  @opt_schema [
    always: [
      type: {:list, @preload_item_type},
      default: [],
      doc: "Always preload these relationships."
    ],
    master: [
      type: {:list, @preload_item_type},
      default: [],
      doc: "Additional preloads for master users."
    ],
    tenant: [
      type: {:list, @preload_item_type},
      default: [],
      doc: "Additional preloads for tenant users."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(preload), do: {:ok, preload}
end

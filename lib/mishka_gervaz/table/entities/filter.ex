defmodule MishkaGervaz.Table.Entities.Filter do
  @moduledoc """
  Entity struct for table filter configuration.
  """

  @type filter_type ::
          :text
          | :select
          | :combobox
          | :multi_select
          | :boolean
          | :number
          | :date
          | :datetime
          | :range

  @type relation_mode :: :static | :search | :search_multi

  @type t :: %__MODULE__{
          name: atom(),
          type: filter_type(),
          source: atom() | nil,
          fields: [atom()] | nil,
          depends_on: atom() | nil,
          visible: boolean() | (map() -> boolean()),
          restricted: boolean() | (map() -> boolean()),
          options: list() | (-> list()) | nil,
          default: any() | nil,
          presets: list() | nil,
          display_field:
            atom() | (struct() -> String.t()) | (struct(), map() -> String.t()) | nil,
          search_field: atom() | nil,
          include_nil: boolean() | String.t(),
          min: integer() | nil,
          max: integer() | nil,
          min_chars: integer(),
          virtual: boolean(),
          resource: module() | nil,
          load_action: atom(),
          load: (Ash.Query.t(), map() -> list()) | nil,
          apply: (Ash.Query.t(), any(), map() -> Ash.Query.t()) | nil,
          mode: relation_mode(),
          page_size: pos_integer(),
          ui: __MODULE__.Ui.t() | nil,
          preload: __MODULE__.Preload.t() | nil,
          type_module: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    type: :text,
    source: nil,
    fields: nil,
    depends_on: nil,
    visible: true,
    restricted: false,
    options: nil,
    default: nil,
    presets: nil,
    display_field: nil,
    search_field: nil,
    include_nil: false,
    min: nil,
    max: nil,
    min_chars: 2,
    virtual: false,
    resource: nil,
    load_action: :read,
    load: nil,
    apply: nil,
    mode: :static,
    page_size: 20,
    ui: nil,
    preload: nil,
    type_module: nil,
    __spark_metadata__: nil
  ]

  @builtin_filter_types [
    :text,
    :select,
    :combobox,
    :multi_select,
    :boolean,
    :number,
    :date,
    :datetime,
    :date_range,
    :range,
    :relation
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Filter identifier."
    ],
    type: [
      type:
        {:or,
         [{:in, @builtin_filter_types}, {:behaviour, MishkaGervaz.Table.Behaviours.FilterType}]},
      default: :text,
      doc: """
      Filter type. Can be a built-in type atom or a custom module implementing FilterType behaviour.

      Built-in types: #{Enum.map_join(@builtin_filter_types, ", ", &inspect/1)}

      Custom type example:
          filter :category, type: MyApp.Table.Filters.TreeSelect
      """
    ],
    source: [
      type: :atom,
      doc: "Source field if different from name."
    ],
    fields: [
      type: {:list, :atom},
      doc: "Search fields for :text type."
    ],
    depends_on: [
      type: :atom,
      doc: "Parent filter for cascading."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Visibility."
    ],
    restricted: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: false,
      doc: "Master-only filter. Boolean or `fn user -> boolean`."
    ],
    options: [
      type: {:or, [{:list, :any}, {:fun, 0}]},
      doc: """
      Manual options list [{label, value}] or a zero-arity function that returns the list.

      A function is resolved once at mount time (page load), useful for dynamic options:

          filter :language, :select do
            options fn ->
              # query DB for distinct values
              [{"English", "en"}, {"Persian", "fa"}]
            end
          end
      """
    ],
    default: [
      type: :any,
      doc: "Default value for the filter. Will be pre-selected on initial load."
    ],
    presets: [
      type: {:list, :any},
      doc: "Range presets [{label, map}]."
    ],
    display_field: [
      type: {:or, [:atom, {:fun, 1}, {:fun, 2}]},
      doc: """
      Field or function to display for relationship options.

      Can be:
      - An atom (field name)
      - A 1-arity function receiving the record
      - A 2-arity function receiving (record, state) for conditional display

          display_field :name
          display_field fn r -> "\#{r.name} - \#{r.site.name}" end
          display_field fn r, state ->
            if state.master_user?, do: "\#{r.name} - \#{r.site.name}", else: r.name
          end
      """
    ],
    search_field: [
      type: :atom,
      doc: "Field to search in (combobox/async)."
    ],
    include_nil: [
      type: {:or, [:boolean, :string]},
      default: false,
      doc: "Include nil option."
    ],
    min: [
      type: :integer,
      doc: "Min value for number type."
    ],
    max: [
      type: :integer,
      doc: "Max value for number type."
    ],
    min_chars: [
      type: :integer,
      default: 2,
      doc: "Min chars before search."
    ],
    virtual: [
      type: :boolean,
      default: false,
      doc: "No database column."
    ],
    resource: [
      type: {:behaviour, Ash.Resource},
      doc: "Resource to load options from (for virtual)."
    ],
    load_action: [
      type: :atom,
      default: :read,
      doc: "Action to load options."
    ],
    load: [
      type: {:fun, 2},
      doc: "Custom load function `fn query, assigns -> options`."
    ],
    apply: [
      type: {:fun, 3},
      doc: "Custom apply function `fn query, value, assigns -> query`."
    ],
    mode: [
      type: {:in, [:static, :load_more, :search, :search_multi]},
      default: :static,
      doc: """
      Loading mode for relation filters.

      - `:static` - Load all options at once (default, for small datasets)
      - `:load_more` - Initial page with "Load more" button
      - `:search` - Type to search with pagination (single select)
      - `:search_multi` - Type to search with pagination (multi select)
      """
    ],
    page_size: [
      type: :pos_integer,
      default: 20,
      doc: "Number of options per page when using paginated modes."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the filter after DSL compilation.
  """
  def transform(%__MODULE__{} = filter) do
    filter = filter |> maybe_set_source() |> resolve_type_module()

    {:ok, filter}
  end

  def transform(filter), do: {:ok, filter}

  defp maybe_set_source(%{source: nil, name: name} = filter) do
    %{filter | source: name}
  end

  defp maybe_set_source(filter), do: filter

  defp resolve_type_module(%{type: type} = filter) do
    type_module = MishkaGervaz.Table.Types.Filter.get_or_passthrough(type)
    %{filter | type_module: type_module}
  end
end

defmodule MishkaGervaz.Table.Entities.Filter.Ui do
  @moduledoc """
  UI configuration for a filter.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          placeholder: String.t() | nil,
          prompt: String.t(),
          disabled_prompt: String.t() | (-> String.t()) | nil,
          icon: String.t() | nil,
          debounce: integer(),
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            placeholder: nil,
            prompt: "Select...",
            disabled_prompt: nil,
            icon: nil,
            debounce: 300,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Filter label. String or `fn -> gettext(...) end` for i18n."
    ],
    placeholder: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Placeholder text. String or `fn -> gettext(...) end` for i18n."
    ],
    prompt: [
      type: :string,
      default: "Select...",
      doc: "Select prompt."
    ],
    disabled_prompt: [
      type: {:or, [{:fun, 0}, :string]},
      doc:
        "Prompt when disabled. Can be a string or a zero-arity function. If not set, will show 'Select {parent label} first'."
    ],
    icon: [
      type: :string,
      doc: "Icon identifier."
    ],
    debounce: [
      type: :integer,
      default: 300,
      doc: "Debounce in milliseconds."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Template-specific options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end

defmodule MishkaGervaz.Table.Entities.Filter.Preload do
  @moduledoc """
  Preload configuration for relation filters.

  Defines which relationships to load for display_field rendering,
  with support for different preloads based on user type.

  ## Example

      filter :media_category_id, :relation do
        display_field fn r -> "\#{r.name} - \#{r.site.name}" end

        preload do
          always [:site]
          tenant [:category]
          master master_category: :category
        end
      end
  """

  @type preload_spec :: atom() | {atom(), atom()} | list()

  @type t :: %__MODULE__{
          always: list(preload_spec()) | nil,
          tenant: list(preload_spec()) | nil,
          master: list(preload_spec()) | nil,
          __spark_metadata__: map() | nil
        }

  defstruct always: nil,
            tenant: nil,
            master: nil,
            __spark_metadata__: nil

  @opt_schema [
    always: [
      type: {:list, :any},
      doc: """
      Relationships to always load, regardless of user type.

      Example: `always [:site, :category]`
      """
    ],
    tenant: [
      type: {:list, :any},
      doc: """
      Relationships to load for tenant users.

      Example: `tenant [:category]`
      """
    ],
    master: [
      type: {:list, :any},
      doc: """
      Relationships to load for master users. Supports renamed relationships.

      Example: `master [:category]` or `master [master_category: :category]`
      """
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(preload), do: {:ok, preload}
end

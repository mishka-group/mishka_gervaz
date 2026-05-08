defmodule MishkaGervaz.Form.Web.State do
  @moduledoc """
  Single state struct for a MishkaGervaz form LiveView.

  All per-request form state lives on `t:t/0`. Instead of scattering values
  across LiveView assigns, every consumer of the form pipeline reads from
  and writes to this struct, giving:

  - One clearly-typed shape (`t:t/0` and `t:Static.t/0`).
  - One place to thread updates (`update/2`).
  - One source of truth for events, the renderer, and tests.

  ## Performance split

  State is partitioned into two halves:

  - `static` (`t:Static.t/0`) — configuration that never changes after
    `init/3`. Same struct reference for the lifetime of the form, which
    lets LiveView skip re-rendering nodes that depend only on it.
  - Dynamic fields — user-interaction state (form values, current step,
    relation options, errors, …) that drive re-renders.

  ## Sub-builders

  `init/3` composes its work from five overridable sub-builder modules.
  The DSL (`state do … end`) can override any of them per-resource, and
  the `use` macro accepts the same set as compile-time options.

  - `MishkaGervaz.Form.Web.State.FieldBuilder` — resolved field configs.
  - `MishkaGervaz.Form.Web.State.GroupBuilder` — group layout.
  - `MishkaGervaz.Form.Web.State.StepBuilder` — wizard / tabs step plan.
  - `MishkaGervaz.Form.Web.State.Presentation` — UI adapter, template,
    theme, features, debounce.
  - `MishkaGervaz.Form.Web.State.Access` — master gate, action mapping,
    preload selection.

  ## Override patterns

  Override the entire state module:

      defmodule MyApp.Form.State do
        use MishkaGervaz.Form.Web.State

        def init(id, resource, user) do
          state = super(id, resource, user)
          MishkaGervaz.Form.Web.State.update(state, mode: :update)
        end
      end

  Use `update/2` (or `struct/2`) to mutate fields — the struct shape is
  fixed and there is no `:custom_field`. To carry your own data, attach
  it to `state.static.config` (read-only, set at build time) or stage it
  on `state.field_values`.

  Override specific sub-builders:

      defmodule MyApp.Form.State do
        use MishkaGervaz.Form.Web.State,
          field: MyApp.Form.FieldBuilder,
          group: MyApp.Form.GroupBuilder
      end

  Or override via DSL:

      mishka_gervaz do
        form do
          state do
            field MyApp.Form.FieldBuilder
            group MyApp.Form.GroupBuilder
          end
        end
      end

  Override entire state module via DSL:

      mishka_gervaz do
        form do
          state module: MyApp.Form.CustomState
        end
      end

  See `MishkaGervaz.Form.Web.State.Helpers` (shared utilities exposed to
  the macro and to user overrides), `MishkaGervaz.Form.Web.Live`,
  `MishkaGervaz.Form.Web.Events`, `MishkaGervaz.Form.Web.DataLoader`,
  `MishkaGervaz.Form.Behaviours.Template`, and the table-side counterpart
  `MishkaGervaz.Table.Web.State`.
  """

  defmodule Static do
    @moduledoc """
    Static form configuration that never changes after initialization.

    Held on `MishkaGervaz.Form.Web.State`'s `:static` field as a separate
    struct so LiveView can skip re-rendering nodes that depend only on
    it — the reference stays identical across every dynamic update,
    enabling O(1) equality comparison.

    Populated once by `MishkaGervaz.Form.Web.State.Default.init/3`. See
    the parent module `MishkaGervaz.Form.Web.State` for the dynamic
    counterpart.
    """

    defstruct [
      :id,
      :resource,
      :stream_name,
      :config,
      :source,
      :fields,
      :groups,
      :steps,
      :uploads,
      :submit,
      :hooks,
      :ui_adapter,
      :ui_adapter_opts,
      :template,
      :theme,
      :features,
      :debounce,
      :preloads,
      :access,
      :layout_mode,
      :layout_columns,
      :layout_navigation,
      :header,
      :footer,
      :notices
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            resource: module(),
            stream_name: atom(),
            config: map(),
            source: map() | nil,
            fields: list(map()),
            groups: list(map()),
            steps: list(map()),
            uploads: list(map()),
            submit: map(),
            hooks: map(),
            ui_adapter: module(),
            ui_adapter_opts: keyword(),
            template: module(),
            theme: map() | nil,
            features: list(atom()),
            debounce: integer() | nil,
            preloads: list(atom()),
            access: module(),
            layout_mode: :standard | :wizard | :tabs,
            layout_columns: 1 | 2 | 3 | 4,
            layout_navigation: :sequential | :free,
            header: map() | nil,
            footer: map() | nil,
            notices: list(map())
          }
  end

  defstruct [
    :static,
    :current_user,
    :master_user?,
    :mode,
    :current_step,
    :step_states,
    :wizard_history,
    :form,
    :loading,
    :errors,
    :form_errors,
    :field_values,
    :relation_options,
    :combobox_options,
    :upload_state,
    :existing_files,
    :dirty?,
    :defaults,
    :preload_aliases,
    :dismissed_notices
  ]

  @type loading_status :: :initial | :loading | :loaded | :error | :denied
  @type form_mode :: :create | :update

  @type t :: %__MODULE__{
          static: Static.t(),
          current_user: map() | nil,
          master_user?: boolean(),
          mode: form_mode(),
          current_step: atom() | nil,
          step_states: %{atom() => :pending | :active | :completed | :error},
          wizard_history: list(atom()),
          form: Phoenix.HTML.Form.t() | nil,
          loading: loading_status(),
          errors: map(),
          form_errors: list(String.t()),
          field_values: map(),
          relation_options: map(),
          combobox_options: %{atom() => list({String.t(), String.t()})},
          upload_state: map(),
          existing_files: %{atom() => list(map())},
          dirty?: boolean(),
          defaults: map() | nil,
          preload_aliases: %{atom() => atom()},
          dismissed_notices: MapSet.t()
        }

  @spec init(String.t(), module(), map() | nil) :: t()
  defdelegate init(id, resource, current_user), to: __MODULE__.Default

  @spec default_init(String.t(), module(), map() | nil) :: t()
  defdelegate default_init(id, resource, current_user), to: __MODULE__.Default

  @spec update(t(), keyword() | map()) :: t()
  defdelegate update(state, updates), to: __MODULE__.Default

  @spec get_action(t(), atom()) :: atom()
  defdelegate get_action(state, action_type), to: __MODULE__.Default

  @spec get_preloads(t()) :: list(atom())
  defdelegate get_preloads(state), to: __MODULE__.Default

  @spec wizard_mode?(t()) :: boolean()
  defdelegate wizard_mode?(state), to: __MODULE__.Default

  @spec tabs_mode?(t()) :: boolean()
  defdelegate tabs_mode?(state), to: __MODULE__.Default

  @spec multi_step?(t()) :: boolean()
  defdelegate multi_step?(state), to: __MODULE__.Default

  @spec current_step_fields(t()) :: list(map())
  defdelegate current_step_fields(state), to: __MODULE__.Default

  @spec current_step_groups(t()) :: list(map())
  defdelegate current_step_groups(state), to: __MODULE__.Default

  defmodule Helpers do
    @moduledoc """
    Shared helpers for `MishkaGervaz.Form.Web.State`.

    Two reasons these live outside the `__using__` macro:

    1. **Reuse across the macro and user overrides.** A user module that
       overrides `init/3` (via `use MishkaGervaz.Form.Web.State`) can
       call any helper here without redefining it. The macro itself
       imports them as `StateHelpers`.
    2. **Smaller compiled bytecode per consumer.** Helpers compile once
       in this module rather than being re-emitted into every macro
       expansion.

    Two functional groups:

    - **Config getters** (`get_layout_mode/1`, `get_uploads/1`,
      `get_submit/1`, …) — pull a typed value out of the runtime
      `Info.config(resource)` map with sensible defaults.
    - **Step helpers** (`groups_for_step/3`) and **access**
      (`mode_allowed?/3`, `resolve_access/1`) — the bits of logic the
      macro and external callers (e.g. `Form.Web.Live`) both need.

    ## `mode_allowed?/3` — `:restricted` semantics

    The `:restricted` field on a `source` map (or a per-mode entry in
    `:access_rules`) accepts two shapes with **deliberately different
    contracts**:

    - `restricted: true` — applies the master gate. Mode is allowed iff
      `state.master_user?`. Use this for the standard "admin-only"
      pattern.
    - `restricted: fn state -> boolean end` — function is the **final
      word**. The master gate is **not** layered on top. Returning
      `true` means "this user is restricted"; the mode is denied.
      Returning `false` allows the mode unconditionally.

    The asymmetry is intentional: the boolean form is the common case
    where you just want master-only; the function form is the escape
    hatch for callers that need the full state (role, dirty?, current
    step, etc.) to decide and don't want master-gate sugar layered on.
    Reach for the boolean unless you specifically need to bypass it.

    See `MishkaGervaz.Form.Web.State`,
    `MishkaGervaz.Form.Web.State.Access.Default`, and
    `MishkaGervaz.Form.Web.Live`.
    """

    require Logger

    import MishkaGervaz.Helpers, only: [module_to_snake: 2]

    @spec generate_stream_name(module()) :: atom()
    def generate_stream_name(resource) do
      resource |> module_to_snake("_form_stream") |> String.to_atom()
    end

    @spec get_layout_mode(map()) :: :standard | :wizard | :tabs
    def get_layout_mode(%{layout: %{mode: mode}}) when mode in [:standard, :wizard, :tabs],
      do: mode

    def get_layout_mode(_config), do: :standard

    @spec get_layout_columns(map()) :: 1 | 2 | 3 | 4
    def get_layout_columns(%{layout: %{columns: cols}}) when cols in [1, 2, 3, 4], do: cols
    def get_layout_columns(_config), do: 1

    @spec get_layout_navigation(map()) :: :sequential | :free
    def get_layout_navigation(%{layout: %{navigation: nav}}) when nav in [:sequential, :free],
      do: nav

    def get_layout_navigation(_config), do: :sequential

    @spec get_uploads(map()) :: list(map())
    def get_uploads(%{uploads: uploads}) when is_list(uploads), do: uploads
    def get_uploads(_config), do: []

    @spec get_header(map()) :: map() | nil
    def get_header(%{layout: %{header: header}}) when is_map(header), do: header
    def get_header(_config), do: nil

    @spec get_footer(map()) :: map() | nil
    def get_footer(%{layout: %{footer: footer}}) when is_map(footer), do: footer
    def get_footer(_config), do: nil

    @spec get_notices(map()) :: list(map())
    def get_notices(%{layout: %{notices: notices}}) when is_list(notices), do: notices
    def get_notices(_config), do: []

    @spec get_submit(map()) :: map()
    def get_submit(%{submit: submit}) when is_map(submit), do: submit

    def get_submit(_config) do
      %{
        create: %{label: "Create", disabled: false, restricted: false, visible: true},
        update: %{label: "Update", disabled: false, restricted: false, visible: true},
        cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
        position: :bottom,
        ui: nil
      }
    end

    @spec get_hooks(map()) :: map()
    def get_hooks(%{hooks: hooks}) when is_map(hooks), do: hooks
    def get_hooks(_config), do: %{}

    @spec groups_for_step(list(map()), list(map()), atom()) :: list(map())
    def groups_for_step(groups, steps, step_name) do
      case Enum.find(steps, &(&1.name == step_name)) do
        %{groups: step_group_names} when is_list(step_group_names) ->
          Enum.filter(groups, &(&1.name in step_group_names))

        _ ->
          groups
      end
    end

    @spec resolve_access(module()) :: module()
    def resolve_access(_resource) do
      MishkaGervaz.Form.Web.State.Access.Default
    end

    @spec mode_allowed?(map() | nil, atom(), map()) :: boolean()
    def mode_allowed?(nil, _mode, _state), do: true

    def mode_allowed?(source, mode, state) do
      cond do
        rule = get_in(source, [:access_rules, mode]) ->
          cond do
            rule[:restricted] -> state.master_user?
            is_function(rule[:condition], 1) -> rule.condition.(state)
            true -> true
          end

        is_function(source[:access_gate], 2) ->
          source.access_gate.(mode, state)

        source[:restricted] == true ->
          state.master_user?

        is_function(source[:restricted], 1) ->
          not source.restricted.(state)

        true ->
          true
      end
    end

    @doc false
    @spec load_static_relation_options(list(map()), map() | nil) :: map()
    def load_static_relation_options(fields, current_user) do
      fields
      |> Enum.filter(&static_relation?/1)
      |> Task.async_stream(
        fn field -> {field.name, load_relation(field, current_user)} end,
        timeout: :infinity,
        ordered: false,
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {name, {:ok, payload}}}, acc -> Map.put(acc, name, payload)
        {:ok, {_name, :error}}, acc -> acc
        {:exit, _reason}, acc -> acc
      end)
    end

    defp load_relation(field, current_user) do
      case Ash.read(field.resource, actor: current_user, authorize?: false, page: false) do
        {:ok, records} ->
          {:ok, build_relation_payload(field, records)}

        {:error, reason} ->
          Logger.warning(
            "[mishka_gervaz] static relation options for field " <>
              "#{inspect(field.name)} (resource #{inspect(field.resource)}) " <>
              "failed to load: #{inspect(reason)}"
          )

          :error
      end
    end

    @doc false
    @spec load_combobox_options(list(map())) :: %{atom() => list()}
    def load_combobox_options(fields) do
      fields
      |> Enum.filter(fn f -> f.type == :combobox and f.options != nil end)
      |> Enum.reduce(%{}, fn field, acc ->
        Map.put(acc, field.name, MishkaGervaz.Helpers.resolve_options(field.options))
      end)
    end

    @doc false
    @spec prepend_nil_option(list(), term()) :: list()
    def prepend_nil_option(options, nil), do: options
    def prepend_nil_option(options, false), do: options
    def prepend_nil_option(options, true), do: [{"(None)", "__nil__"} | options]

    def prepend_nil_option(options, label) when is_binary(label) do
      [{label, "__nil__"} | options]
    end

    def prepend_nil_option(options, label) when is_function(label, 0) do
      [{MishkaGervaz.Helpers.resolve_label(label), "__nil__"} | options]
    end

    defp static_relation?(%{type: :relation, resource: resource} = field)
         when not is_nil(resource) do
      (Map.get(field, :mode) || :static) == :static
    end

    defp static_relation?(_field), do: false

    defp build_relation_payload(field, records) do
      display_field = field.display_field || :name

      options =
        records
        |> Enum.map(fn record ->
          label = to_string(Map.get(record, display_field, Map.get(record, :id)))
          value = to_string(record.id)
          {label, value}
        end)
        |> prepend_nil_option(field.include_nil)

      %{
        options: options,
        has_more?: false,
        page: 1,
        selected_options: [],
        dropdown_open?: false
      }
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias MishkaGervaz.Form.Web.State
      alias MishkaGervaz.Form.Web.State.Static
      alias MishkaGervaz.Form.Web.State.Helpers, as: StateHelpers
      alias MishkaGervaz.Resource.Info.Form, as: Info

      @__field_builder__ Keyword.get(
                           opts,
                           :field,
                           MishkaGervaz.Form.Web.State.FieldBuilder.Default
                         )
      @__group_builder__ Keyword.get(
                           opts,
                           :group,
                           MishkaGervaz.Form.Web.State.GroupBuilder.Default
                         )
      @__step_builder__ Keyword.get(
                          opts,
                          :step,
                          MishkaGervaz.Form.Web.State.StepBuilder.Default
                        )
      @__presentation__ Keyword.get(
                          opts,
                          :presentation,
                          MishkaGervaz.Form.Web.State.Presentation.Default
                        )
      @__access__ Keyword.get(
                    opts,
                    :access,
                    MishkaGervaz.Form.Web.State.Access.Default
                  )

      @spec field_builder() :: module()
      def field_builder, do: @__field_builder__

      @spec group_builder() :: module()
      def group_builder, do: @__group_builder__

      @spec step_builder() :: module()
      def step_builder, do: @__step_builder__

      @spec presentation() :: module()
      def presentation, do: @__presentation__

      @spec access() :: module()
      def access, do: @__access__

      @spec init(String.t(), module(), map() | nil) :: State.t()
      def init(id, resource, current_user) do
        dsl_state = Info.state(resource)

        case Map.get(dsl_state, :module) do
          nil ->
            do_init(id, resource, current_user, dsl_state)

          custom_module ->
            custom_module.init(id, resource, current_user)
        end
      end

      @spec default_init(String.t(), module(), map() | nil) :: State.t()
      def default_init(id, resource, current_user) do
        dsl_state = Info.state(resource) |> Map.delete(:module)
        do_init(id, resource, current_user, dsl_state)
      end

      @spec do_init(String.t(), module(), map() | nil, map()) :: State.t()
      defp do_init(id, resource, current_user, dsl_state) do
        config = Info.config(resource)
        modules = resolve_dsl_modules(dsl_state)
        master_user? = modules.access.master_user?(current_user)

        fields = modules.field.build(config, resource)

        groups =
          config
          |> modules.group.build(resource)
          |> modules.group.assign_fields_to_groups(fields)

        steps = modules.step.build(config, resource)
        static = build_static(id, resource, config, modules, fields, groups, steps, master_user?)
        {current_step, step_states} = initial_step_state(static.layout_mode, steps, modules.step)

        %State{
          static: static,
          current_user: current_user,
          master_user?: master_user?,
          mode: :create,
          current_step: current_step,
          step_states: step_states,
          wizard_history: if(current_step, do: [current_step], else: []),
          form: nil,
          loading: :initial,
          errors: %{},
          form_errors: [],
          field_values: %{},
          relation_options: StateHelpers.load_static_relation_options(fields, current_user),
          combobox_options: StateHelpers.load_combobox_options(fields),
          upload_state: %{},
          existing_files: %{},
          dirty?: false,
          defaults: nil,
          preload_aliases: Info.preload_aliases(resource, master_user?),
          dismissed_notices: MapSet.new()
        }
      end

      @spec resolve_dsl_modules(map()) :: %{
              field: module(),
              group: module(),
              step: module(),
              presentation: module(),
              access: module()
            }
      defp resolve_dsl_modules(dsl_state) do
        %{
          field: Map.get(dsl_state, :field, field_builder()),
          group: Map.get(dsl_state, :group, group_builder()),
          step: Map.get(dsl_state, :step, step_builder()),
          presentation: Map.get(dsl_state, :presentation, presentation()),
          access: Map.get(dsl_state, :access, access())
        }
      end

      @spec build_static(
              String.t(),
              module(),
              map(),
              map(),
              list(map()),
              list(map()),
              list(map()),
              boolean()
            ) :: Static.t()
      defp build_static(id, resource, config, modules, fields, groups, steps, master_user?) do
        presentation_mod = modules.presentation

        %Static{
          id: id,
          resource: resource,
          stream_name: Info.stream_name(resource) || StateHelpers.generate_stream_name(resource),
          config: config,
          source: config[:source],
          fields: fields,
          groups: groups,
          steps: steps,
          uploads: StateHelpers.get_uploads(config),
          submit: StateHelpers.get_submit(config),
          hooks: StateHelpers.get_hooks(config),
          ui_adapter: presentation_mod.resolve_ui_adapter(config),
          ui_adapter_opts: presentation_mod.get_ui_adapter_opts(config),
          template: presentation_mod.resolve_template(config),
          theme: presentation_mod.get_theme(config),
          features: presentation_mod.get_features(config),
          debounce: presentation_mod.get_debounce(config),
          preloads: modules.access.get_preloads(resource, master_user?),
          access: modules.access,
          layout_mode: StateHelpers.get_layout_mode(config),
          layout_columns: StateHelpers.get_layout_columns(config),
          layout_navigation: StateHelpers.get_layout_navigation(config),
          header: StateHelpers.get_header(config),
          footer: StateHelpers.get_footer(config),
          notices: StateHelpers.get_notices(config)
        }
      end

      @spec initial_step_state(atom(), list(map()), module()) :: {atom() | nil, map()}
      defp initial_step_state(mode, steps, step_mod) when mode in [:wizard, :tabs] do
        {step_mod.initial_step(steps), step_mod.initial_step_states(steps)}
      end

      defp initial_step_state(_mode, _steps, _step_mod), do: {nil, %{}}

      @spec update(State.t(), keyword() | map()) :: State.t()
      def update(%State{} = state, updates), do: struct(state, updates)

      @spec get_action(State.t(), atom()) :: atom()
      def get_action(
            %State{
              static: %{resource: resource, access: access_mod},
              master_user?: master_user?
            },
            action_type
          ) do
        access_mod.get_action(resource, action_type, master_user?)
      end

      @spec get_preloads(State.t()) :: list(atom())
      def get_preloads(%State{
            static: %{resource: resource, access: access_mod},
            master_user?: master_user?
          }) do
        access_mod.get_preloads(resource, master_user?)
      end

      @spec wizard_mode?(State.t()) :: boolean()
      def wizard_mode?(%State{static: %{layout_mode: :wizard}}), do: true
      def wizard_mode?(_), do: false

      @spec tabs_mode?(State.t()) :: boolean()
      def tabs_mode?(%State{static: %{layout_mode: :tabs}}), do: true
      def tabs_mode?(_), do: false

      @spec multi_step?(State.t()) :: boolean()
      def multi_step?(%State{static: %{layout_mode: mode}}) when mode in [:wizard, :tabs],
        do: true

      def multi_step?(_), do: false

      @spec current_step_fields(State.t()) :: list(map())
      def current_step_fields(%State{current_step: nil, static: %{fields: fields}}), do: fields

      def current_step_fields(%State{
            current_step: step_name,
            static: %{groups: groups, steps: steps, fields: fields}
          }) do
        step_groups = StateHelpers.groups_for_step(groups, steps, step_name)
        step_field_names = Enum.flat_map(step_groups, &Map.get(&1, :fields, []))
        field_names = MapSet.new(step_field_names)

        if MapSet.size(field_names) == 0 do
          fields
        else
          Enum.filter(fields, &MapSet.member?(field_names, &1.name))
        end
      end

      @spec current_step_groups(State.t()) :: list(map())
      def current_step_groups(%State{current_step: nil, static: %{groups: groups}}), do: groups

      def current_step_groups(%State{
            current_step: step_name,
            static: %{groups: groups, steps: steps}
          }) do
        StateHelpers.groups_for_step(groups, steps, step_name)
      end

      defoverridable field_builder: 0,
                     group_builder: 0,
                     step_builder: 0,
                     presentation: 0,
                     access: 0,
                     init: 3,
                     default_init: 3,
                     update: 2,
                     get_action: 2,
                     get_preloads: 1,
                     wizard_mode?: 1,
                     tabs_mode?: 1,
                     multi_step?: 1,
                     current_step_fields: 1,
                     current_step_groups: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.State
end

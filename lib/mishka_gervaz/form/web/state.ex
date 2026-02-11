defmodule MishkaGervaz.Form.Web.State do
  @moduledoc """
  Single state struct for MishkaGervaz form.

  Instead of scattered assigns, all form state is managed in this struct.
  This provides:

  - Clear state structure
  - Easy state updates
  - Type safety
  - Single source of truth

  ## Performance Optimization

  State is split into two parts:
  - `static` - Configuration that never changes (same reference for O(1) comparison)
  - Dynamic fields - User interaction state that triggers re-renders

  This separation allows LiveView to skip re-rendering static parts (fields, groups, etc.)
  when only dynamic state (form values, current step, etc.) changes.

  ## Sub-builders

  State initialization is composed of sub-builders that can be overridden:

  - `FieldBuilder` - Builds field configs from DSL and resource
  - `GroupBuilder` - Builds group layout
  - `StepBuilder` - Builds wizard steps
  - `Presentation` - Resolves UI adapter and templates
  - `Access` - Handles access control

  ## User Override

  Override the entire state module:

      defmodule MyApp.Form.State do
        use MishkaGervaz.Form.Web.State

        def init(id, resource, user) do
          state = super(id, resource, user)
          %{state | custom_field: :value}
        end
      end

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
  """

  alias MishkaGervaz.Resource.Info.Form, as: Info

  import MishkaGervaz.Helpers, only: [module_to_snake: 2]

  defmodule Static do
    @moduledoc """
    Static form configuration that never changes after initialization.

    Stored as a separate struct so LiveView can skip re-rendering when only
    dynamic state changes. The reference to this struct stays the same across
    all state updates, enabling O(1) equality comparison.
    """

    defstruct [
      :id,
      :resource,
      :stream_name,
      :config,
      :fields,
      :field_order,
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
      :preloads,
      :layout_mode,
      :layout_columns,
      :layout_navigation,
      :layout_persistence
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            resource: module(),
            stream_name: atom(),
            config: map(),
            fields: list(map()),
            field_order: list(atom()),
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
            preloads: list(atom()),
            layout_mode: :standard | :wizard | :tabs,
            layout_columns: 1 | 2 | 3 | 4,
            layout_navigation: :sequential | :free,
            layout_persistence: :none | :ets | :client_token
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
    :field_values,
    :relation_options,
    :upload_state,
    :dirty?
  ]

  @type loading_status :: :initial | :loading | :loaded | :error
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
          field_values: map(),
          relation_options: map(),
          upload_state: map(),
          dirty?: boolean()
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
    Helper functions for Form State module operations.

    These are extracted from the macro to allow users to reuse them
    when overriding state functions.
    """

    alias MishkaGervaz.Form.Web.State
    alias MishkaGervaz.Resource.Info.Form, as: Info

    import MishkaGervaz.Helpers, only: [module_to_snake: 2]

    @spec generate_stream_name(module()) :: atom()
    def generate_stream_name(resource) do
      resource |> module_to_snake("_form_stream") |> String.to_atom()
    end

    @spec get_layout_mode(map()) :: :standard | :wizard | :tabs
    def get_layout_mode(config) do
      case config do
        %{layout: %{mode: mode}} when mode in [:standard, :wizard, :tabs] -> mode
        _ -> :standard
      end
    end

    @spec get_layout_columns(map()) :: 1 | 2 | 3 | 4
    def get_layout_columns(config) do
      case config do
        %{layout: %{columns: cols}} when cols in [1, 2, 3, 4] -> cols
        _ -> 1
      end
    end

    @spec get_layout_navigation(map()) :: :sequential | :free
    def get_layout_navigation(config) do
      case config do
        %{layout: %{navigation: nav}} when nav in [:sequential, :free] -> nav
        _ -> :sequential
      end
    end

    @spec get_layout_persistence(map()) :: :none | :ets | :client_token
    def get_layout_persistence(config) do
      case config do
        %{layout: %{persistence: p}} when p in [:none, :ets, :client_token] -> p
        _ -> :none
      end
    end

    @spec get_uploads(map()) :: list(map())
    def get_uploads(config) do
      case config do
        %{uploads: uploads} when is_list(uploads) -> uploads
        _ -> []
      end
    end

    @spec get_submit(map()) :: map()
    def get_submit(config) do
      case config do
        %{submit: submit} when is_map(submit) ->
          submit

        _ ->
          %{
            create_label: "Create",
            update_label: "Update",
            cancel_label: "Cancel",
            show_cancel: true,
            position: :bottom,
            ui: nil
          }
      end
    end

    @spec get_hooks(map()) :: map()
    def get_hooks(config) do
      case config do
        %{hooks: hooks} when is_map(hooks) -> hooks
        _ -> %{}
      end
    end

    @spec fields_for_step(list(map()), list(map()), atom()) :: list(map())
    def fields_for_step(groups, fields, _step_name) do
      step_group_names =
        groups
        |> Enum.filter(fn g -> g.name in (Map.get(g, :step, nil) |> List.wrap()) end)
        |> Enum.flat_map(&(&1[:fields] || []))

      if step_group_names == [] do
        fields
      else
        field_names = MapSet.new(step_group_names)
        Enum.filter(fields, &MapSet.member?(field_names, &1.name))
      end
    end

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
        do_init(id, resource, current_user)
      end

      @spec default_init(String.t(), module(), map() | nil) :: State.t()
      def default_init(id, resource, current_user) do
        do_init(id, resource, current_user)
      end

      @spec do_init(String.t(), module(), map() | nil) :: State.t()
      defp do_init(id, resource, current_user) do
        config = Info.config(resource)

        field_mod = field_builder()
        group_mod = group_builder()
        step_mod = step_builder()
        presentation_mod = presentation()
        access_mod = access()

        master_user? = access_mod.master_user?(current_user)
        preloads = access_mod.get_preloads(resource, master_user?)

        fields = field_mod.build(config, resource)
        field_order = Enum.map(fields, & &1.name)
        groups = group_mod.build(config, resource)
        groups = group_mod.assign_fields_to_groups(groups, fields)

        steps = step_mod.build(config, resource)
        layout_mode = StateHelpers.get_layout_mode(config)

        template = presentation_mod.resolve_template(config)
        stream_name = Info.stream_name(resource) || StateHelpers.generate_stream_name(resource)

        static = %Static{
          id: id,
          resource: resource,
          stream_name: stream_name,
          config: config,
          fields: fields,
          field_order: field_order,
          groups: groups,
          steps: steps,
          uploads: StateHelpers.get_uploads(config),
          submit: StateHelpers.get_submit(config),
          hooks: StateHelpers.get_hooks(config),
          ui_adapter: presentation_mod.resolve_ui_adapter(config),
          ui_adapter_opts: presentation_mod.get_ui_adapter_opts(config),
          template: template,
          theme: presentation_mod.get_theme(config),
          features: presentation_mod.get_features(config),
          preloads: preloads,
          layout_mode: layout_mode,
          layout_columns: StateHelpers.get_layout_columns(config),
          layout_navigation: StateHelpers.get_layout_navigation(config),
          layout_persistence: StateHelpers.get_layout_persistence(config)
        }

        current_step =
          if layout_mode in [:wizard, :tabs], do: step_mod.initial_step(steps), else: nil

        step_states =
          if layout_mode in [:wizard, :tabs], do: step_mod.initial_step_states(steps), else: %{}

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
          field_values: %{},
          relation_options: %{},
          upload_state: %{},
          dirty?: false
        }
      end

      @spec update(State.t(), keyword() | map()) :: State.t()
      def update(%State{} = state, updates), do: struct(state, updates)

      @spec get_action(State.t(), atom()) :: atom()
      def get_action(
            %State{static: %{resource: resource}, master_user?: master_user?},
            action_type
          ) do
        access().get_action(resource, action_type, master_user?)
      end

      @spec get_preloads(State.t()) :: list(atom())
      def get_preloads(%State{static: %{resource: resource}, master_user?: master_user?}) do
        access().get_preloads(resource, master_user?)
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

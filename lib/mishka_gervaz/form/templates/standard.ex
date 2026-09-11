defmodule MishkaGervaz.Form.Templates.Standard do
  @moduledoc """
  Default form template for MishkaGervaz.

  Implements `MishkaGervaz.Form.Behaviours.Template` and serves as the
  out-of-the-box renderer for every `mishka_gervaz form do … end` block.
  Custom templates inherit from this module via `use
  MishkaGervaz.Form.Behaviours.Template`, which delegates the four
  optional callbacks (`render_loading/1`, `render_field/1`,
  `render_group/1`, `render_step_indicator/1`) here.

  ## Layout modes

    * `:standard` — single-page form, fields rendered in their declared
      groups (or flat when no groups are declared).
    * `:wizard`   — multi-step form with a sequential step indicator and
      step-aware submit / next / previous buttons.
    * `:tabs`     — same step structure as `:wizard` but with free
      navigation between tabs.

  Mode selection is read from `@state.static.layout_mode`. The render
  pipeline (`render/1`) dispatches notices (`render_notices_at/2`),
  the form header / footer chrome, the body (`render_groups/1` or
  `render_current_step_groups/1`), upload sections, and submit buttons
  in a fixed order so notice positioning stays predictable.

  ## Two-axis composition

    * **Template** (this module) — *where* things go: groups, steps,
      notices, submit area.
    * **UI adapter** (e.g. `MishkaGervaz.UIAdapters.Tailwind`) — *how*
      things look: every concrete element (`field_group`, `alert`,
      `button`, `step_indicator`, …) is dispatched through
      `MishkaGervaz.Helpers.dynamic_component/1`, which forwards to the
      adapter declared on the resource.

  ## Field-type dispatch

  `render_field/1` delegates per-type rendering to modules under
  `MishkaGervaz.Form.Types.Field.*` (e.g.
  `MishkaGervaz.Form.Types.Field.Hidden`,
  `MishkaGervaz.Form.Types.Field.Relation`). Built-in types are wired
  through `render_input/4`; custom types implement
  `MishkaGervaz.Form.Behaviours.FieldType` and are referenced directly
  in the field DSL (`field :foo, MyApp.FieldTypes.Color`).

  ## Input scoping

  `render_input/4` puts `:table_id` — the UI adapter's name for the scope a control belongs to —
  on the base assigns of every field, alongside the `:id` taken from the Phoenix form field. The
  adapter's searchable controls (`search_select`, `load_more_select`, `multi_select`, `combobox`,
  `string_list_input`) build their wrapper id from that scope plus the field name, so two forms on
  one page may share a field name without their ids colliding.

  `render_string_list_input/4` sets the same scope itself, since it builds its assigns from the
  template assigns rather than from that base.

  ## Upload progress

  `render_upload_entries/1` sets its track width with an inline `style="width: N%"` rather than a
  Tailwind width class, as does `MishkaGervaz.UIAdapters.Tailwind.upload_progress/1`.

  See `MishkaGervaz.Form.Behaviours.Template`,
  `MishkaGervaz.Form.Behaviours.FieldType`,
  `MishkaGervaz.Behaviours.UIAdapter`,
  `MishkaGervaz.Helpers`, and
  `MishkaGervaz.Form.Web.UploadHelpers`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.Template
  use Phoenix.Component
  use MishkaGervaz.Messages
  alias Phoenix.LiveView.JS

  import MishkaGervaz.Helpers,
    only: [
      get_ui_label: 1,
      dynamic_component: 1,
      resolve_label: 1,
      has_value?: 1,
      find_by_name: 2,
      resolve_ui_label: 1,
      accessible?: 2,
      format_filesize: 1
    ]

  import MishkaGervaz.Form.Web.UploadHelpers, only: [has_uploads?: 1, namespaced_upload_name: 2]

  alias MishkaGervaz.Form.Web.UploadHelpers

  @impl true
  def name, do: :standard

  @impl true
  def label, do: "Standard Form"

  @impl true
  def icon, do: "hero-document-text"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :init_js, resolve_js_hook(assigns, :on_init))

    ~H"""
    <div id={@static.id <> "-form-wrapper"} phx-mounted={@init_js} hidden={@state.loading == :denied}>
      <%= cond do %>
        <% @state.loading == :denied -> %>
        <% @state.loading == :loaded and @state.form -> %>
          <%= if @state.static.layout_mode in [:wizard, :tabs] do %>
            {render_step_indicator(assigns)}
          <% end %>

          <.form
            for={@state.form}
            id={@static.id <> "-form"}
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            multipart={has_uploads?(@static)}
          >
            {render_notices_at(assigns, :form_top)}
            {render_notices_at(assigns, :before_header)}
            {render_form_header(assigns)}
            {render_notices_at(assigns, :after_header)}
            {render_notices_at(assigns, :before_groups)}

            <%= if @state.static.layout_mode == :standard do %>
              {render_groups(assigns)}
            <% else %>
              {render_current_step_groups(assigns)}
            <% end %>

            {render_uploads_section(assigns)}
            {render_notices_at(assigns, :before_submit)}
            {render_submit(assigns)}
            {render_notices_at(assigns, :form_bottom)}
          </.form>
          {render_form_footer(assigns)}
          {render_notices_at(assigns, :form_footer)}
        <% true -> %>
          {render_loading(assigns)}
      <% end %>
    </div>
    """
  end

  @impl true
  def render_loading(assigns) do
    assigns = assign(assigns, :ui, assigns.static.ui_adapter)

    ~H"""
    <div class="flex items-center justify-center p-8">
      <.dynamic_component module={@ui} function={:spinner} size={:lg} />
    </div>
    """
  end

  @impl true
  def render_field(assigns) do
    field = assigns.field
    form = assigns.state.form

    assigns =
      assigns
      |> assign(:field_config, field)
      |> assign(:form_field, form[field.name])
      |> assign(:label, get_ui_label(field))
      |> assign(:errors, Map.get(assigns.state.errors, field.name, []))
      |> assign(:ui, assigns.static.ui_adapter)

    render_field_by_type(assigns)
  end

  @impl true
  def render_group(assigns) do
    group = assigns.group
    mode = assigns.state.mode
    group_fields = Map.get(group, :resolved_fields, [])

    visible_fields =
      Enum.filter(group_fields, fn field ->
        accessible?(field, assigns.state) and show_on_mode?(field, mode)
      end)

    if visible_fields == [] do
      ~H""
    else
      group_class = get_in(group, [:ui, :class])

      assigns =
        assigns
        |> assign(:group_label, Map.get(group, :resolved_label))
        |> assign(:group_fields, group_fields)
        |> assign(:group_columns, get_in(group, [:ui, :columns]))
        |> assign(:ui, assigns.static.ui_adapter)
        |> assign(:collapsible, Map.get(group, :collapsible, false))
        |> assign(:has_group_class, not is_nil(group_class))
        |> assign(:group_class, group_class || "")

      ~H"""
      <div>
        <%= if @has_group_class do %>
          <.dynamic_component
            module={@ui}
            function={:field_group}
            label={@group_label}
            class={@group_class}
            collapsible={@collapsible}
            open={true}
          >
            {render_group_fields(assigns, @group_fields, @group_columns)}
          </.dynamic_component>
        <% else %>
          <.dynamic_component
            module={@ui}
            function={:field_group}
            label={@group_label}
            collapsible={@collapsible}
            open={true}
          >
            {render_group_fields(assigns, @group_fields, @group_columns)}
          </.dynamic_component>
        <% end %>
      </div>
      """
    end
  end

  @impl true
  def render_step_indicator(assigns) do
    steps = assigns.static.steps

    step_data =
      Enum.map(steps, fn step ->
        %{
          name: step.name,
          label: Map.get(step, :resolved_label, to_string(step.name)),
          status: Map.get(assigns.state.step_states, step.name, :pending)
        }
      end)

    assigns =
      assigns
      |> assign(:step_data, step_data)
      |> assign(:current_step, assigns.state.current_step)
      |> assign(:ui, assigns.static.ui_adapter)

    ~H"""
    <div class="mb-6">
      <.dynamic_component
        module={@ui}
        function={:step_indicator}
        steps={@step_data}
        current={@current_step}
      />
    </div>
    """
  end

  defp render_groups(assigns) do
    groups = assigns.static.groups

    if groups == [] do
      render_group_fields(assigns, assigns.static.fields, nil)
    else
      visible_groups = Enum.filter(groups, &accessible?(&1, assigns.state))

      grouped_names =
        groups
        |> Enum.flat_map(&Map.get(&1, :fields, []))
        |> MapSet.new()

      ungrouped_fields =
        Enum.reject(assigns.static.fields, &MapSet.member?(grouped_names, &1.name))

      assigns =
        assigns
        |> assign(:all_groups, visible_groups)
        |> assign(:ungrouped_fields, ungrouped_fields)

      ~H"""
      <div>
        <%= for group <- @all_groups do %>
          <% group_assigns = assign(assigns, :group, group) %>
          {render_notices_at(assigns, {:before_group, group.name})}
          {render_group(group_assigns)}
          {render_notices_at(assigns, {:after_group, group.name})}
        <% end %>
        <%= if @ungrouped_fields != [] do %>
          {render_group_fields(assigns, @ungrouped_fields, nil)}
        <% end %>
      </div>
      """
    end
  end

  defp render_current_step_groups(assigns) do
    current_step = assigns.state.current_step
    steps = assigns.static.steps
    groups = assigns.static.groups

    step_groups =
      case Enum.find(steps, &(&1.name == current_step)) do
        %{groups: group_names} when is_list(group_names) ->
          Enum.filter(groups, &(&1.name in group_names and accessible?(&1, assigns.state)))

        _ ->
          Enum.filter(groups, &accessible?(&1, assigns.state))
      end

    assigns = assign(assigns, :step_groups, step_groups)

    ~H"""
    <div>
      <%= for group <- @step_groups do %>
        <% ga = assign(assigns, :group, group) %>
        {render_notices_at(assigns, {:before_group, group.name})}
        {render_group(ga)}
        {render_notices_at(assigns, {:after_group, group.name})}
      <% end %>
    </div>
    """
  end

  @doc false
  def render_form_header(assigns) do
    case assigns.static.header do
      nil ->
        ~H""

      header ->
        if chrome_visible?(header, assigns.state) do
          do_render_form_header(assigns, header)
        else
          ~H""
        end
    end
  end

  defp do_render_form_header(assigns, header) do
    case header.render do
      fun when is_function(fun, 1) ->
        fun.(assigns)

      fun when is_function(fun, 2) ->
        fun.(assigns, assigns.state)

      _ ->
        title = resolve_dynamic(header.title, assigns.state)
        description = resolve_dynamic(header.description, assigns.state)

        if is_nil(title) and is_nil(description) do
          ~H""
        else
          assigns =
            assigns
            |> assign(:header_title, title)
            |> assign(:header_description, description)
            |> assign(:header_icon, header.icon)
            |> assign(:header_class, header.class)
            |> assign(:ui, assigns.static.ui_adapter)

          ~H"""
          <.dynamic_component
            module={@ui}
            function={:form_header}
            title={@header_title}
            description={@header_description}
            icon={@header_icon}
            class={@header_class}
          />
          """
        end
    end
  end

  @doc false
  def render_form_footer(assigns) do
    case assigns.static.footer do
      nil ->
        ~H""

      footer ->
        if chrome_visible?(footer, assigns.state) do
          do_render_form_footer(assigns, footer)
        else
          ~H""
        end
    end
  end

  defp do_render_form_footer(assigns, footer) do
    case footer.render do
      fun when is_function(fun, 1) ->
        fun.(assigns)

      fun when is_function(fun, 2) ->
        fun.(assigns, assigns.state)

      _ ->
        content = resolve_dynamic(footer.content, assigns.state)

        if is_nil(content) do
          ~H""
        else
          assigns =
            assigns
            |> assign(:footer_content, content)
            |> assign(:footer_class, footer.class)
            |> assign(:ui, assigns.static.ui_adapter)

          ~H"""
          <.dynamic_component
            module={@ui}
            function={:form_footer}
            content={@footer_content}
            class={@footer_class}
          />
          """
        end
    end
  end

  @doc false
  def render_notices_at(assigns, position) do
    notices =
      assigns.static.notices
      |> Enum.filter(&(&1.position == position))
      |> Enum.filter(&notice_visible?(&1, assigns.state))

    assigns = assign(assigns, :notices_at_position, notices)

    ~H"""
    <%= for notice <- @notices_at_position do %>
      {render_notice(assigns, notice)}
    <% end %>
    """
  end

  defp render_notice(assigns, notice) do
    case notice.render do
      fun when is_function(fun, 1) ->
        assigns
        |> assign(:notice, notice)
        |> fun.()

      fun when is_function(fun, 2) ->
        assigns_with = assign(assigns, :notice, notice)
        fun.(assigns_with, assigns.state)

      _ ->
        title = resolve_dynamic(notice.title, assigns.state)
        content = resolve_dynamic(notice.content, assigns.state)
        notice_ui = notice.ui || %{}

        assigns =
          assigns
          |> assign(:notice_type, notice.type)
          |> assign(:notice_title, title)
          |> assign(:notice_content, content)
          |> assign(:notice_icon, notice.icon)
          |> assign(:notice_dismissible, notice.dismissible)
          |> assign(:notice_name, notice.name)
          |> assign(:notice_class, Map.get(notice_ui, :class))
          |> assign(:ui, assigns.static.ui_adapter)

        ~H"""
        <div class="mb-4">
          <.dynamic_component
            module={@ui}
            function={:alert}
            type={@notice_type}
            title={@notice_title}
            content={@notice_content}
            icon={@notice_icon}
            dismissible={@notice_dismissible}
            dismiss_event="dismiss_notice"
            dismiss_value={to_string(@notice_name)}
            phx_target={@myself}
            class={@notice_class}
          />
        </div>
        """
    end
  end

  defp notice_visible?(notice, state) do
    cond do
      not chrome_visible?(notice, state) ->
        false

      MapSet.member?(state.dismissed_notices || MapSet.new(), notice.name) ->
        false

      not step_match?(notice, state) ->
        false

      not bind_to_active?(notice, state) ->
        false

      is_function(notice.show_when, 1) ->
        notice.show_when.(state)

      true ->
        true
    end
  end

  defp chrome_visible?(entity, state) do
    restricted_ok? =
      case Map.get(entity, :restricted) do
        true -> state.master_user?
        fun when is_function(fun, 1) -> not fun.(state)
        _ -> true
      end

    visible_ok? =
      case Map.get(entity, :visible) do
        false -> false
        fun when is_function(fun, 1) -> fun.(state)
        _ -> true
      end

    restricted_ok? and visible_ok?
  end

  defp step_match?(%{only_steps: nil}, _state), do: true
  defp step_match?(%{only_steps: []}, _state), do: true

  defp step_match?(%{only_steps: steps}, %{current_step: current}) when is_list(steps),
    do: current in steps

  defp step_match?(_, _), do: true

  defp bind_to_active?(%{bind_to: nil}, _state), do: true

  defp bind_to_active?(%{bind_to: :validation}, state) do
    has_form_errors?(state) or has_field_errors?(state) or has_changeset_errors?(state)
  end

  defp bind_to_active?(%{bind_to: :dirty}, %{dirty?: dirty?}), do: dirty? == true

  defp bind_to_active?(%{bind_to: :uploads}, %{upload_state: upload_state})
       when is_map(upload_state) do
    Enum.any?(upload_state, fn
      {_k, %{errors: errs}} when is_list(errs) -> errs != []
      _ -> false
    end)
  end

  defp bind_to_active?(_, _), do: true

  defp has_form_errors?(%{form_errors: errors}) when is_list(errors), do: errors != []
  defp has_form_errors?(_), do: false

  defp has_field_errors?(%{errors: errors}) when is_map(errors) do
    Enum.any?(errors, fn
      {_k, v} when is_list(v) -> v != []
      {_k, v} when is_binary(v) -> v != ""
      _ -> false
    end)
  end

  defp has_field_errors?(_), do: false

  defp has_changeset_errors?(%{form: %{source: %{submitted_once?: true} = source}}) do
    case source do
      %{errors: errors} when is_list(errors) -> errors != []
      _ -> false
    end
  end

  defp has_changeset_errors?(_), do: false

  defp resolve_dynamic(nil, _state), do: nil
  defp resolve_dynamic(value, _state) when is_binary(value), do: value
  defp resolve_dynamic(fun, _state) when is_function(fun, 0), do: fun.()
  defp resolve_dynamic(fun, state) when is_function(fun, 1), do: fun.(state)
  defp resolve_dynamic(value, _state), do: value

  defp render_group_fields(assigns, fields, group_columns) do
    columns = group_columns || assigns.static.layout_columns
    mode = assigns.state.mode

    visible_fields =
      Enum.filter(fields, fn field ->
        accessible?(field, assigns.state) and show_on_mode?(field, mode)
      end)

    col_class =
      if group_columns do
        group_col_class(min(group_columns, max(length(visible_fields), 1)))
      else
        global_col_class(columns)
      end

    assigns =
      assigns
      |> assign(:col_class, col_class)
      |> assign(:render_fields, visible_fields)

    ~H"""
    <div class={@col_class}>
      <%= for field <- @render_fields do %>
        <% fa = assign(assigns, :field, field) %>
        <div class={nested_span_class(get_in_map(field, [:ui, :span]))}>
          {render_field(fa)}
        </div>
      <% end %>
    </div>
    """
  end

  defp group_col_class(1), do: "grid gap-4"
  defp group_col_class(2), do: "grid sm:grid-cols-2 gap-4"
  defp group_col_class(3), do: "grid sm:grid-cols-3 gap-4"
  defp group_col_class(4), do: "grid sm:grid-cols-2 md:grid-cols-4 gap-4"
  defp group_col_class(_), do: "grid gap-4"

  defp global_col_class(1), do: "grid gap-4"
  defp global_col_class(2), do: "grid md:grid-cols-2 gap-4"
  defp global_col_class(3), do: "grid md:grid-cols-2 lg:grid-cols-3 gap-4"
  defp global_col_class(4), do: "grid md:grid-cols-2 lg:grid-cols-4 gap-4"
  defp global_col_class(_), do: "grid gap-4"

  # Draws one control per declared key through the UI adapter, reading each held value under
  # either a string or an atom key.
  defp key_map_inputs(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-2.5">
      <div :for={key <- @keys} class={(key.type == :textarea && "col-span-2") || ""}>
        <label
          class="mb-[5px] block text-[10px] font-bold text-[#8a877f]"
          for={"#{@input_id}_#{key.name}"}
        >
          {key.label || MishkaGervaz.Helpers.humanize(key.name)}
        </label>
        {key_map_input(
          @ui,
          key,
          "#{@input_name}[#{key.name}]",
          "#{@input_id}_#{key.name}",
          Map.get(@held, to_string(key.name), Map.get(@held, key.name))
        )}
      </div>
    </div>
    """
  end

  defp key_list_rows(assigns) do
    ~H"""
    <div class="space-y-[9px]">
      <div
        :for={{row, index} <- Enum.with_index(@rows)}
        class="rounded-[11px] border border-[#ecebe6] bg-[#fbfbf9] p-3"
      >
        <div class="mb-2 flex items-center justify-between gap-3">
          <span class="text-[10px] font-bold text-[#a8a5a0]">{index + 1}</span>
          <button
            :if={@editable?}
            type="button"
            phx-target={@target}
            class="inline-flex h-6 shrink-0 items-center rounded-[7px] px-2 text-[11px] font-semibold text-[#c0392b] transition-colors hover:bg-[#fdf4f3]"
            {row_event(@owner, :remove, index)}
          >
            {@remove_label || dgettext("mishka_gervaz", "Remove")}
          </button>
        </div>
        <.key_map_inputs
          ui={@ui}
          keys={@keys}
          held={row}
          input_name={"#{@input_name}[#{index}]"}
          input_id={"#{@input_id}_#{index}"}
        />
      </div>

      <input :if={@editable?} type="hidden" name={"#{@input_name}[_empty]"} value="1" />

      <button
        :if={@editable?}
        type="button"
        phx-target={@target}
        class="inline-flex h-9 w-full items-center justify-center rounded-[11px] border border-dashed border-[#dcdbf5] bg-[#f7f6fd] text-[11.5px] font-semibold text-[#4f4bcc] transition-colors hover:border-[#c3c1f0] hover:bg-[#f2f1fc]"
        {row_event(@owner, :add, nil)}
      >
        {@add_label || dgettext("mishka_gervaz", "+ Add")}
      </button>
    </div>
    """
  end

  # The phx-click attributes for a key list's add and remove buttons: `add_nested`/`remove_nested`
  # for a top-level list, `add_key_row`/`remove_key_row` for one nested inside a row.
  defp row_event(%{kind: :top, field: field}, :add, _index),
    do: %{"phx-click" => "add_nested", "phx-value-field" => field}

  defp row_event(%{kind: :top, field: field}, :remove, index),
    do: %{
      "phx-click" => "remove_nested",
      "phx-value-field" => field,
      "phx-value-index" => index
    }

  defp row_event(%{kind: :sub} = owner, :add, _index),
    do: %{
      "phx-click" => "add_key_row",
      "phx-value-field" => owner.field,
      "phx-value-index" => owner.index,
      "phx-value-sub" => owner.sub
    }

  defp row_event(%{kind: :sub} = owner, :remove, index),
    do: %{
      "phx-click" => "remove_key_row",
      "phx-value-field" => owner.field,
      "phx-value-index" => owner.index,
      "phx-value-sub" => owner.sub,
      "phx-value-row" => index
    }

  defp row_event(_no_owner, _which, _index), do: %{}

  # Renders one key's control through the adapter, from an assigns map built here.
  defp key_map_input(ui, key, name, id, value) do
    %{__changed__: nil, module: ui, name: name, id: id, value: value}
    |> Map.merge(key_map_control(key, value))
    |> dynamic_component()
  end

  # The adapter assigns a key's type asks for: which component draws it, and its options.
  defp key_map_control(%{type: :toggle}, value),
    do: %{function: :toggle_input, checked: ticked?(value)}

  defp key_map_control(%{type: :checkbox}, value),
    do: %{
      function: :checkbox,
      value: "true",
      checked: ticked?(value),
      hidden_input: true,
      label: nil
    }

  defp key_map_control(%{type: :select} = key, _value),
    do: %{function: :select, options: key.options, prompt: key.placeholder || ""}

  defp key_map_control(%{type: :textarea} = key, _value),
    do: %{function: :textarea, rows: 2, placeholder: key.placeholder}

  defp key_map_control(%{type: :number} = key, _value),
    do: %{function: :number_input, placeholder: key.placeholder}

  defp key_map_control(key, _value),
    do: %{function: :text_input, placeholder: key.placeholder}

  defp ticked?(value), do: value in [true, "true", "on"]

  defp nested_span_class(nil), do: nil
  defp nested_span_class(1), do: "col-span-1"
  defp nested_span_class(2), do: "col-span-2"
  defp nested_span_class(3), do: "col-span-3"
  defp nested_span_class(4), do: "col-span-4"
  defp nested_span_class(_), do: nil

  defp busy_label(button, static) do
    cond do
      is_map(button) and is_binary(button[:loading_label]) ->
        button[:loading_label]

      static.uploads not in [nil, []] ->
        dgettext("mishka_gervaz", "Uploading…")

      true ->
        dgettext("mishka_gervaz", "Saving…")
    end
  end

  defp render_submit(%{static: %{submit_visible?: false}, state: %{mode: :create}} = assigns) do
    ~H""
  end

  defp render_submit(assigns) do
    submit = assigns.static.submit
    mode = assigns.state.mode
    state = assigns.state
    layout_mode = assigns.static.layout_mode

    submit_button = if mode == :create, do: submit[:create], else: submit[:update]
    cancel_button = submit[:cancel]

    show_submit =
      submit_button != nil and
        evaluate_button_active(submit_button, state) and
        evaluate_button_visible(submit_button, state) and
        not evaluate_button_restricted(submit_button, state)

    show_cancel =
      cancel_button != nil and
        (state.mode == :update or state.dirty?) and
        evaluate_button_active(cancel_button, state) and
        evaluate_button_visible(cancel_button, state) and
        not evaluate_button_restricted(cancel_button, state)

    submit_label =
      if show_submit, do: resolve_label(submit_button[:label]) || "Submit", else: ""

    cancel_label =
      if show_cancel, do: resolve_label(cancel_button[:label]) || "Cancel", else: ""

    submit_disabled = show_submit and evaluate_button_disabled(submit_button, state)
    cancel_disabled = show_cancel and evaluate_button_disabled(cancel_button, state)

    cancel_js =
      assigns
      |> resolve_js_hook(:on_cancel)
      |> JS.push("cancel", target: assigns.myself)

    assigns =
      assigns
      |> assign(:submit_label, submit_label)
      |> assign(:submit_busy_label, busy_label(submit_button, assigns.static))
      |> assign(:cancel_label, cancel_label)
      |> assign(:show_submit, show_submit)
      |> assign(:show_cancel, show_cancel)
      |> assign(:submit_disabled, submit_disabled)
      |> assign(:cancel_disabled, cancel_disabled)
      |> assign(:show_step_nav, layout_mode in [:wizard, :tabs])
      |> assign(:alternatives, alternatives_for(assigns.static, state, submit_disabled))
      |> assign(:alt_menu_id, assigns.static.id <> "-submit-alternatives")
      |> assign(:ui, assigns.static.ui_adapter)
      |> assign(:cancel_js, cancel_js)

    ~H"""
    <div class="mt-6 flex items-center justify-between">
      <div class="flex gap-2">
        <.dynamic_component
          :if={@show_step_nav}
          module={@ui}
          function={:step_navigation}
          current_step={@state.current_step}
          steps={@static.steps}
          step_states={@state.step_states}
          myself={@myself}
        />
      </div>

      <div class="flex items-center gap-[14px]">
        <.dynamic_component
          :if={@show_cancel}
          module={@ui}
          function={:button}
          label={@cancel_label}
          type="button"
          class="px-1.5 py-2 text-[13px] font-semibold text-[#8a877f] transition-colors hover:text-[#1b1a18]"
          disabled={@cancel_disabled}
          phx_click={@cancel_js}
          phx_target={@myself}
        />

        <span :if={@show_submit and (not @show_step_nav or last_step?(assigns))} class="relative flex">
          <button
            type="submit"
            disabled={@submit_disabled}
            phx-disable-with={@submit_busy_label}
            class={[
              "inline-flex h-[42px] items-center gap-2 px-[18px] text-[12.5px] font-bold text-white transition-opacity",
              (@alternatives == [] && "rounded-[11px]") || "rounded-l-[11px]",
              "disabled:cursor-wait disabled:opacity-70",
              if(@submit_disabled,
                do: "cursor-not-allowed bg-[#c3c0b8]",
                else:
                  "bg-[linear-gradient(140deg,#6d69e6,#4f4bcc)] shadow-[0_5px_14px_rgba(79,75,204,0.28)] hover:opacity-95"
              )
            ]}
          >
            <svg
              width="15"
              height="15"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M20 6 9 17l-5-5" />
            </svg>
            {@submit_label}
          </button>

          <button
            :if={@alternatives != []}
            type="button"
            id={@alt_menu_id <> "-toggle"}
            phx-click={JS.toggle(to: "#" <> @alt_menu_id)}
            title="Other ways to create this"
            class="grid h-[42px] w-8 flex-none place-items-center rounded-r-[11px] border-l border-white/25 bg-[linear-gradient(140deg,#6d69e6,#4f4bcc)] text-white hover:opacity-95"
          >
            <svg
              width="12"
              height="12"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.6"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="m6 9 6 6 6-6" />
            </svg>
          </button>

          <div
            :if={@alternatives != []}
            id={@alt_menu_id}
            phx-click-away={JS.hide(to: "#" <> @alt_menu_id)}
            phx-window-keydown={JS.hide(to: "#" <> @alt_menu_id)}
            phx-key="escape"
            class="absolute bottom-[50px] right-0 z-50 hidden w-[268px] rounded-[13px] border border-[#ecebe6] bg-white p-1.5 shadow-[0_18px_46px_rgba(20,18,26,.22)]"
          >
            <.alternative :for={alt <- @alternatives} alt={alt} />
          </div>
        </span>
      </div>
    </div>
    """
  end

  defp alternatives_for(%{submit_alternatives: alternatives}, %{mode: :create}, false)
       when is_list(alternatives),
       do: alternatives

  defp alternatives_for(%{submit_alternatives: alternatives}, %{mode: :create}, true)
       when is_list(alternatives),
       do: Enum.filter(alternatives, &Map.has_key?(&1, :navigate))

  defp alternatives_for(_static, _state, _submit_disabled), do: []

  attr :alt, :map, required: true

  defp alternative(%{alt: %{navigate: path}} = assigns) do
    assigns = assign(assigns, :path, path)

    ~H"""
    <.link
      id={@alt.id}
      navigate={@path}
      class="flex w-full items-start gap-2.5 rounded-[9px] p-[9px] text-left hover:bg-[#f6f5f2]"
    >
      <.alternative_text alt={@alt} />
    </.link>
    """
  end

  defp alternative(assigns) do
    ~H"""
    <button
      type="submit"
      id={@alt.id}
      name={@alt.name}
      value={@alt.value}
      class="flex w-full items-start gap-2.5 rounded-[9px] p-[9px] text-left hover:bg-[#f6f5f2]"
    >
      <.alternative_text alt={@alt} />
    </button>
    """
  end

  attr :alt, :map, required: true

  defp alternative_text(assigns) do
    ~H"""
    <span class="min-w-0 flex-1">
      <span class="block text-[12px] font-semibold text-[#1b1a18]">{@alt.label}</span>
      <span
        :if={@alt[:description]}
        class="mt-0.5 block text-[10.5px] font-medium leading-[1.45] text-[#6d6a63]"
      >
        {@alt.description}
      </span>
    </span>
    """
  end

  defp render_uploads_section(assigns) do
    uploads = assigns.static.uploads

    if is_list(uploads) and uploads != [] do
      inline_names =
        assigns.static.fields
        |> Enum.filter(fn f -> f.type == :upload end)
        |> MapSet.new(fn f -> f.name end)

      remaining = Enum.reject(uploads, fn u -> u.name in inline_names end)

      if remaining == [] do
        ~H""
      else
        ui = assigns.static.ui_adapter
        upload_items = build_upload_items(remaining, assigns)
        assigns = assigns |> assign(:upload_items, upload_items) |> assign(:ui, ui)

        ~H"""
        <div class="space-y-4 mt-4">
          <%= for item <- @upload_items do %>
            <% ua = build_upload_assigns(assigns, item) %>
            {render_upload_by_style(ua)}
          <% end %>
        </div>
        """
      end
    else
      ~H""
    end
  end

  defp build_upload_items(uploads, assigns) do
    Enum.reduce(uploads, [], fn upload_config, acc ->
      ns_name = namespaced_upload_name(upload_config.name, assigns.static.id)
      upload_ref = assigns.uploads[ns_name]

      if upload_ref do
        [%{config: upload_config, ref: upload_ref, ns_name: ns_name} | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  defp build_upload_assigns(assigns, item) do
    assigns
    |> assign(:upload_config, item.config)
    |> assign(:upload, item.ref)
    |> assign(:ns_name, item.ns_name)
    |> assign(:style, item.config[:style] || :dropzone)
    |> assign(:existing_files, Map.get(assigns.state.existing_files, item.config.name, []))
    |> assign(:ui, assigns.static.ui_adapter)
  end

  defp render_field_by_type(assigns) do
    ui = assigns.ui
    field = assigns.field_config
    form_field = assigns.form_field
    label = assigns.label
    errors = assigns.errors

    if field_disabled?(field, assigns.state) do
      is_loading = relation_loading?(field, assigns.state)
      disabled_prompt = get_disabled_prompt(field, assigns.static.fields, is_loading)

      assigns =
        assigns
        |> assign(:wrapper_label, label)
        |> assign(:wrapper_errors, [])
        |> assign(:wrapper_required, Map.get(field, :required, false))
        |> assign(:disabled_prompt, disabled_prompt)
        |> assign(:is_loading, is_loading)

      ~H"""
      <.dynamic_component
        module={@ui}
        function={:field_wrapper}
        label={@wrapper_label}
        errors={@wrapper_errors}
        required={@wrapper_required}
      >
        <div
          :if={@is_loading}
          data-role="gervaz-field-skeleton"
          aria-busy="true"
          class="flex h-11 w-full items-center rounded-[11px] border border-[#f0efea] bg-[#faf9f6] px-[14px]"
        >
          <span class="h-[9px] w-2/5 animate-pulse rounded-full bg-[#f2f1ec]" aria-hidden="true" />
          <span class="sr-only">{@disabled_prompt}</span>
        </div>

        <div
          :if={!@is_loading}
          class="flex h-11 w-full cursor-not-allowed items-center gap-2 rounded-[11px] border border-[#ecebe6] bg-[#f6f5f2] px-[14px] text-[13px] font-medium text-[#8a877f]"
        >
          {@disabled_prompt}
        </div>
      </.dynamic_component>
      """
    else
      assigns =
        assigns
        |> assign(:wrapper_label, label)
        |> assign(:wrapper_errors, errors)
        |> assign(:wrapper_required, Map.get(field, :required, false))
        |> assign(:rendered_input, render_input(ui, field, form_field, assigns))

      ~H"""
      <.dynamic_component
        module={@ui}
        function={:field_wrapper}
        label={@wrapper_label}
        errors={@wrapper_errors}
        required={@wrapper_required}
      >
        {@rendered_input}
      </.dynamic_component>
      """
    end
  end

  defp show_on_mode?(%{show_on: nil}, _mode), do: true
  defp show_on_mode?(%{show_on: mode}, mode), do: true
  defp show_on_mode?(%{show_on: _}, _mode), do: false
  defp show_on_mode?(_, _), do: true

  defp field_disabled?(%{depends_on: nil}, _state), do: false

  defp field_disabled?(%{depends_on: depends_on} = field, state) do
    parent = find_by_name(state.static.fields, depends_on)

    cond do
      parent && !accessible?(parent, state) -> false
      !has_value?(Map.get(state.field_values, depends_on)) -> true
      relation_loading?(field, state) -> true
      true -> false
    end
  end

  defp field_disabled?(_, _), do: false

  defp relation_loading?(%{type: :relation, name: name}, state) do
    case Map.get(state.relation_options, name) do
      %{loading?: true} -> true
      _ -> false
    end
  end

  defp relation_loading?(_, _), do: false

  defp get_disabled_prompt(field, all_fields, is_loading)

  defp get_disabled_prompt(_field, _all_fields, true),
    do: dgettext("mishka_gervaz", "Loading options...")

  defp get_disabled_prompt(%{ui: %{disabled_prompt: prompt}}, _, _) when is_binary(prompt),
    do: prompt

  defp get_disabled_prompt(%{ui: %{disabled_prompt: prompt}}, _, _) when is_function(prompt, 0),
    do: prompt.()

  defp get_disabled_prompt(%{depends_on: depends_on}, all_fields, _)
       when not is_nil(depends_on) do
    parent_label =
      case find_by_name(all_fields, depends_on) do
        nil -> nil
        parent -> resolve_ui_label(parent)
      end

    field_name = parent_label || Phoenix.Naming.humanize(depends_on)
    dgettext("mishka_gervaz", "Select %{field} first", field: field_name)
  end

  defp get_disabled_prompt(_, _, _),
    do: dgettext("mishka_gervaz", "Select parent field first")

  defp render_input(ui, field, form_field, assigns) do
    type = Map.get(field, :type, :text)

    debounce = get_in_map(field, [:ui, :debounce]) || assigns.static.debounce
    is_readonly = evaluate_readonly(field, assigns.state)

    base =
      assigns
      |> assign(:field, form_field)
      |> assign(:name, form_field.name)
      |> assign(:id, form_field.id)
      |> assign(:table_id, assigns.static.id)
      |> assign(:value, Phoenix.HTML.Form.input_value(assigns.state.form, field.name))
      |> assign(:placeholder, resolve_label(get_in_map(field, [:ui, :placeholder])))
      |> assign(:autocomplete, get_in_map(field, [:ui, :autocomplete]))
      |> assign(:disabled, is_readonly)
      |> assign(:module, ui)
      |> assign(:phx_debounce, debounce)
      |> assign(:extra, get_in_map(field, [:ui, :extra]) || %{})
      |> put_present(:rows, get_in_map(field, [:ui, :rows]))

    case type do
      :password ->
        base
        |> assign(:disabled, false)
        |> assign(:readonly, is_readonly)
        |> assign(:function, :password_input)
        |> assign(:autocomplete, get_in_map(field, [:ui, :autocomplete]) || "new-password")
        |> dynamic_component()

      t when t in [:text, :email, :url, :tel, :hidden] ->
        base
        |> assign(:disabled, false)
        |> assign(:readonly, is_readonly)
        |> assign(:function, :text_input)
        |> assign(:type, to_string(t))
        |> dynamic_component()

      :number ->
        base
        |> assign(:disabled, false)
        |> assign(:readonly, is_readonly)
        |> assign(:function, :number_input)
        |> dynamic_component()

      :textarea ->
        base
        |> assign(:disabled, false)
        |> assign(:readonly, is_readonly)
        |> assign(:function, :textarea)
        |> dynamic_component()

      :select ->
        options = resolve_field_options(field)
        base |> assign(:function, :select) |> assign(:options, options) |> dynamic_component()

      :multi_select ->
        options = resolve_field_options(field)

        base
        |> assign(:function, :multi_select)
        |> assign(:options, options)
        |> dynamic_component()

      :checkbox ->
        form_value = Phoenix.HTML.Form.input_value(assigns.state.form, field.name)

        base
        |> assign(:value, "true")
        |> assign(:checked, form_value in [true, "true"])
        |> assign(:hidden_input, true)
        |> assign(:function, :checkbox)
        |> dynamic_component()

      :toggle ->
        form_value = Phoenix.HTML.Form.input_value(assigns.state.form, field.name)

        base
        |> assign(:value, "true")
        |> assign(:checked, form_value in [true, "true"])
        |> assign(:function, :toggle_input)
        |> dynamic_component()

      :date ->
        base
        |> assign(:disabled, false)
        |> assign(:readonly, is_readonly)
        |> assign(:function, :date_input)
        |> dynamic_component()

      :datetime ->
        base
        |> assign(:disabled, false)
        |> assign(:readonly, is_readonly)
        |> assign(:function, :datetime_input)
        |> dynamic_component()

      :range ->
        min = get_in_map(field, [:ui, :min]) || 0
        max = get_in_map(field, [:ui, :max]) || 100

        base
        |> assign(:function, :range_input)
        |> assign(:min, min)
        |> assign(:max, max)
        |> dynamic_component()

      :json ->
        raw_value = Phoenix.HTML.Form.input_value(assigns.state.form, field.name)

        json_value =
          case raw_value do
            v when is_map(v) or is_list(v) -> Jason.encode!(v, pretty: true)
            v when is_binary(v) -> v
            nil -> ""
            v -> inspect(v)
          end

        base
        |> assign(:value, json_value)
        |> assign(:function, :json_editor)
        |> dynamic_component()

      :relation ->
        alias MishkaGervaz.Form.Types.Field.Relation, as: RelationType

        rel_data = Map.get(assigns.state.relation_options, field.name, %{})
        current_value = Phoenix.HTML.Form.input_value(assigns.state.form, field.name)
        readonly = evaluate_readonly(field, assigns.state)

        state_assigns = %{
          form_field: form_field,
          form_id: assigns.static.id,
          myself: assigns[:myself],
          field_values: assigns.state.field_values,
          current_value: current_value,
          readonly: readonly
        }

        RelationType.render_input(field, rel_data, state_assigns, ui)

      :search_select ->
        options = Map.get(assigns.state.relation_options, field.name, %{})

        base
        |> assign(:function, :search_select)
        |> assign(:options, Map.get(options, :options, []))
        |> dynamic_component()

      :combobox ->
        options = Map.get(assigns.state.combobox_options, field.name, [])

        base
        |> assign(:function, :combobox)
        |> assign(:options, options)
        |> assign(:field_name, field.name)
        |> assign(:target, assigns[:myself])
        |> dynamic_component()

      :file ->
        render_upload_field(ui, field, form_field, assigns)

      :upload ->
        render_upload_field(ui, field, form_field, assigns)

      :string_list ->
        render_string_list_input(ui, field, form_field, assigns)

      :key_map ->
        render_key_map_input(field, form_field, assigns)

      :key_list ->
        render_key_list_input(field, form_field, assigns)

      :nested ->
        render_nested_input(ui, field, form_field, assigns)

      _ ->
        base |> assign(:function, :text_input) |> assign(:type, "text") |> dynamic_component()
    end
  end

  defp render_upload_field(ui, field, form_field, assigns) do
    upload_config = UploadHelpers.find_upload_for_field(assigns.static, field.name)

    if upload_config do
      ns_name = namespaced_upload_name(upload_config.name, assigns.static.id)
      upload_ref = assigns.uploads[ns_name]
      style = upload_config[:style] || :dropzone
      existing = Map.get(assigns.state.existing_files, upload_config.name, [])

      upload_assigns =
        assigns
        |> assign(:upload_config, upload_config)
        |> assign(:upload, upload_ref)
        |> assign(:ns_name, ns_name)
        |> assign(:style, style)
        |> assign(:existing_files, existing)
        |> assign(:ui, ui)

      render_upload_by_style(upload_assigns)
    else
      assigns
      |> assign(:module, ui)
      |> assign(:function, :text_input)
      |> assign(:name, form_field.name)
      |> assign(:id, form_field.id)
      |> assign(:value, "")
      |> assign(:type, "file")
      |> dynamic_component()
    end
  end

  defp render_string_list_input(ui, field, _form_field, assigns) do
    items =
      case Map.get(assigns.state.field_values, field.name) do
        list when is_list(list) ->
          list

        _ ->
          case Phoenix.HTML.Form.input_value(assigns.state.form, field.name) do
            list when is_list(list) -> Enum.reject(list, &is_nil/1)
            nil -> []
            "" -> []
            value when is_binary(value) -> [value]
          end
      end

    assigns
    |> assign(:module, ui)
    |> assign(:function, :string_list_input)
    |> assign(:items, items)
    |> assign(:table_id, assigns.static.id)
    |> assign(:field_name, to_string(field.name))
    |> assign(:disabled, evaluate_readonly(field, assigns.state))
    |> assign(:add_label, resolve_label(field.add_label) || "+ Add")
    |> assign(:remove_label, resolve_label(field.remove_label) || "Remove")
    |> assign(:placeholder, resolve_label(get_in_map(field, [:ui, :placeholder])))
    |> assign(:target, assigns[:myself])
    |> dynamic_component()
  end

  # Draws a top-level `:key_map` field: one row of controls, under the field's own input name.
  defp render_key_map_input(field, form_field, assigns) do
    held = Phoenix.HTML.Form.input_value(assigns.state.form, field.name)

    assigns
    |> assign(:ui, assigns.static.ui_adapter)
    |> assign(:keys, MishkaGervaz.Form.Types.Field.KeyMap.keys(field))
    |> assign(:held, ((is_map(held) and not is_struct(held)) && held) || %{})
    |> assign(:input_name, form_field.name)
    |> assign(:input_id, form_field.id)
    |> key_map_inputs()
  end

  # Draws a top-level `:key_list` field over an `{:array, :map}` column: one row of controls per
  # entry, with add and remove buttons wired by `row_event/3`.
  defp render_key_list_input(field, form_field, assigns) do
    readonly? = evaluate_readonly(field, assigns.state)

    assigns
    |> assign(:ui, assigns.static.ui_adapter)
    |> assign(:keys, MishkaGervaz.Form.Types.Field.KeyList.keys(field))
    |> assign(
      :rows,
      MishkaGervaz.Form.Types.Field.KeyList.rows(
        Phoenix.HTML.Form.input_value(assigns.state.form, field.name)
      )
    )
    |> assign(:editable?, not readonly?)
    |> assign(:add_label, resolve_nested_label(field, :add_label, nil))
    |> assign(:remove_label, resolve_nested_label(field, :remove_label, nil))
    |> assign(:owner, (readonly? && nil) || %{kind: :top, field: to_string(field.name)})
    |> assign(:input_name, form_field.name)
    |> assign(:input_id, form_field.id)
    |> assign(:target, assigns[:myself])
    |> key_list_rows()
  end

  defp render_nested_input(ui, field, form_field, assigns) do
    nested_source = get_in_map(field, [:ui, :extra, :nested_source]) || :embedded

    if nested_source == :constrained_map do
      render_constrained_map_nested(field, assigns)
    else
      render_embedded_nested(ui, field, form_field, assigns)
    end
  end

  attr(:title, :string, required: true)
  attr(:removable, :boolean, required: true)
  attr(:remove_label, :string, required: true)
  attr(:target, :any, default: nil)

  attr(:path, :string, default: nil)
  attr(:field, :string, default: nil)
  attr(:index, :string, default: nil)

  slot(:inner_block, required: true)

  defp nested_card(assigns) do
    ~H"""
    <div class="rounded-[14px] border border-[#ecebe6] bg-white p-4">
      <div class="mb-[14px] flex items-start justify-between gap-3">
        <span class="text-[12px] font-bold text-[#3a382f]">{@title}</span>
        <button
          :if={@removable}
          type="button"
          phx-click="remove_nested"
          phx-value-path={@path}
          phx-value-field={@field}
          phx-value-index={@index}
          phx-target={@target}
          class="inline-flex h-7 shrink-0 items-center rounded-[8px] px-[9px] text-[11.5px] font-semibold text-[#c0392b] transition-colors hover:bg-[#fdf4f3]"
        >
          {@remove_label}
        </button>
      </div>
      <div class="grid gap-x-4 gap-y-[14px] md:grid-cols-2">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr(:show, :boolean, required: true)
  attr(:label, :string, required: true)
  attr(:path, :string, default: nil)
  attr(:field, :string, default: nil)
  attr(:target, :any, default: nil)

  defp nested_add(assigns) do
    ~H"""
    <button
      :if={@show}
      type="button"
      phx-click="add_nested"
      phx-value-path={@path}
      phx-value-field={@field}
      phx-target={@target}
      class="inline-flex h-10 w-full items-center justify-center gap-[7px] rounded-[11px] border border-dashed border-[#dcdbf5] bg-[#f7f6fd] text-[12px] font-semibold text-[#4f4bcc] transition-colors hover:border-[#c3c1f0] hover:bg-[#f2f1fc]"
    >
      {@label}
    </button>
    """
  end

  defp entry_title(name, :array, index), do: "#{Phoenix.Naming.humanize(name)} #{index + 1}"
  defp entry_title(name, _mode, _index), do: Phoenix.Naming.humanize(name)

  defp render_embedded_nested(_ui, field, _form_field, assigns) do
    nested_fields = Map.get(field, :nested_fields, [])
    parent_readonly = evaluate_readonly(field, assigns.state)
    nested_mode = get_in_map(field, [:ui, :extra, :nested_mode]) || :array

    assigns =
      assigns
      |> assign(:nested_field, field)
      |> assign(:sub_fields, sub_fields(nested_fields, parent_readonly, assigns.state))
      |> assign(:form_path, assigns.state.form.name <> "[#{field.name}]")
      |> assign(:nested_mode, nested_mode)
      |> assign(:removable?, nested_mode == :array and not parent_readonly)
      |> assign(:add_label, resolve_nested_label(field, :add_label, "+ Add"))
      |> assign(:remove_label, resolve_nested_label(field, :remove_label, "Remove"))
      |> assign(:target, assigns[:myself])

    ~H"""
    <div class="space-y-[10px]">
      <.inputs_for :let={nested_form} field={@state.form[@nested_field.name]}>
        <.nested_card
          title={entry_title(@nested_field.name, @nested_mode, nested_form.index)}
          removable={@removable?}
          remove_label={@remove_label}
          path={nested_form.name}
          target={@target}
        >
          <%= for sf <- @sub_fields do %>
            {render_sub_field(assigns, sf,
              name: nested_form[sf.name].name,
              id: nested_form[sf.name].id,
              value: nested_form[sf.name].value,
              errors: []
            )}
          <% end %>
        </.nested_card>
      </.inputs_for>

      <.nested_add show={@removable?} label={@add_label} path={@form_path} target={@target} />
    </div>
    """
  end

  defp render_constrained_map_nested(field, assigns) do
    nested_fields = Map.get(field, :nested_fields, [])
    nested_mode = get_in_map(field, [:ui, :extra, :nested_mode]) || :array
    parent_readonly = evaluate_readonly(field, assigns.state)

    assigns =
      assigns
      |> assign(:nested_field, field)
      |> assign(:sub_fields, sub_fields(nested_fields, parent_readonly, assigns.state))
      |> assign(:entries, judged_entries(field, nested_fields, assigns.state))
      |> assign(:form_name, assigns.state.form.name)
      |> assign(:removable?, nested_mode == :array and not parent_readonly)
      |> assign(:add_label, resolve_nested_label(field, :add_label, "+ Add"))
      |> assign(:remove_label, resolve_nested_label(field, :remove_label, "Remove"))
      |> assign(:target, assigns[:myself])

    ~H"""
    <div class="space-y-[10px]">
      <.nested_card
        :for={{idx, entry, errors} <- @entries}
        title={entry_title(@nested_field.name, :array, idx)}
        removable={@removable?}
        remove_label={@remove_label}
        field={to_string(@nested_field.name)}
        index={to_string(idx)}
        target={@target}
      >
        <%= for sf <- @sub_fields do %>
          {render_sub_field(assigns, sf,
            name: "#{@form_name}[#{@nested_field.name}][#{idx}][#{sf.name}]",
            id: "#{@static.id}_#{@form_name}_#{@nested_field.name}_#{idx}_#{sf.name}",
            value: get_entry_value(entry, sf.name),
            errors: Map.get(errors, sf.name, []),
            field: to_string(@nested_field.name),
            index: to_string(idx)
          )}
        <% end %>
      </.nested_card>

      <.nested_add
        show={@removable?}
        label={@add_label}
        field={to_string(@nested_field.name)}
        target={@target}
      />
    </div>
    """
  end

  defp sub_fields(nested_fields, parent_readonly, state),
    do: Enum.map(nested_fields, &extract_sub_field_info(&1, parent_readonly, state))

  defp judged_entries(field, nested_fields, state) do
    error_mode = %{required: submitted_once?(state), type: true}

    field.name
    |> get_map_entries(state.form)
    |> Enum.map(fn {idx, entry} ->
      {idx, entry, compute_sub_field_errors(entry, nested_fields, error_mode)}
    end)
  end

  defp submitted_once?(%{form: %{source: %{submitted_once?: submitted}}}), do: submitted
  defp submitted_once?(_state), do: false

  # Draws one sub-field of a nested row. `opts[:field]` and `opts[:index]` name the owning row, and
  # are nil on the embedded path.
  defp render_sub_field(assigns, sf, opts) do
    assigns
    |> assign(:sf, sf)
    |> assign(:ui, assigns.static.ui_adapter)
    |> assign(:input_name, opts[:name])
    |> assign(:input_id, opts[:id])
    |> assign(:input_value, opts[:value])
    |> assign(:sub_errors, opts[:errors] || [])
    |> assign(:owner_field, opts[:field])
    |> assign(:owner_index, opts[:index])
    |> assign(:target, assigns[:myself])
    |> sub_field()
  end

  defp sub_field(%{sf: %{visible: false}} = assigns), do: ~H""

  defp sub_field(%{sf: %{type: :hidden}} = assigns) do
    ~H"""
    <input type="hidden" name={@input_name} id={@input_id} value={@input_value} />
    """
  end

  defp sub_field(assigns) do
    ~H"""
    <div class={nested_span_class(@sf.span)}>
      <label class="mb-[7px] block text-[10.5px] font-bold text-[#8a877f]" for={@input_id}>
        {@sf.label}<span :if={@sf.required} class="ml-0.5 text-[#e5484d]">*</span>
      </label>
      <div class={@sub_errors != [] && "rounded-[11px] ring-1 ring-[#f0dcd8]"}>
        {sub_field_input(assigns)}
      </div>
      <p :for={err <- @sub_errors} class="mt-[6px] text-[11.5px] font-medium text-[#c0392b]">
        {err}
      </p>
    </div>
    """
  end

  defp sub_field_input(%{sf: %{type: :textarea}} = assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :textarea)
    |> assign(:rows, assigns.sf.rows || 3)
    |> assign(:placeholder, assigns.sf.placeholder)
    |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :key_map}} = assigns) do
    assigns
    |> assign(:keys, MishkaGervaz.Form.Types.Field.KeyMap.keys(assigns.sf))
    |> assign(:held, (is_map(assigns.input_value) && assigns.input_value) || %{})
    |> key_map_inputs()
  end

  defp sub_field_input(%{sf: %{type: :key_list}} = assigns) do
    editable? = is_binary(assigns.owner_field) and not assigns.sf.readonly

    assigns
    |> assign(:keys, MishkaGervaz.Form.Types.Field.KeyList.keys(assigns.sf))
    |> assign(:rows, MishkaGervaz.Form.Types.Field.KeyList.rows(assigns.input_value))
    |> assign(:editable?, editable?)
    |> assign(:add_label, assigns.sf.add_label)
    |> assign(:remove_label, assigns.sf.remove_label)
    |> assign(
      :owner,
      (editable? &&
         %{
           kind: :sub,
           field: assigns.owner_field,
           index: assigns.owner_index,
           sub: assigns.sf.name
         }) || nil
    )
    |> key_list_rows()
  end

  defp sub_field_input(%{sf: %{type: :json}} = assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :json_editor)
    |> assign(:rows, assigns.sf.rows || 3)
    |> assign(:value, encode_json_value(assigns.input_value))
    |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :select}} = assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :select)
    |> assign(:options, assigns.sf.options || [])
    |> assign(:prompt, assigns.sf.placeholder)
    |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :checkbox}} = assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :checkbox)
    |> assign(:value, "true")
    |> assign(:checked, assigns.input_value in [true, "true"])
    |> assign(:hidden_input, true)
    |> assign(:label, nil)
    |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :toggle}} = assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :toggle_input)
    |> assign(:checked, assigns.input_value in [true, "true"])
    |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :number}} = assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :number_input)
    |> assign(:placeholder, assigns.sf.placeholder)
    |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :range}} = assigns) do
    assigns |> sub_field_base() |> assign(:function, :range_input) |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :date}} = assigns) do
    assigns |> sub_field_base() |> assign(:function, :date_input) |> dynamic_component()
  end

  defp sub_field_input(%{sf: %{type: :datetime}} = assigns) do
    assigns |> sub_field_base() |> assign(:function, :datetime_input) |> dynamic_component()
  end

  defp sub_field_input(assigns) do
    assigns
    |> sub_field_base()
    |> assign(:function, :text_input)
    |> assign(:placeholder, assigns.sf.placeholder)
    |> dynamic_component()
  end

  defp sub_field_class(_ui, _type, nil), do: nil
  defp sub_field_class(_ui, _type, ""), do: nil

  defp sub_field_class(ui, :textarea, extra),
    do: adapter_class(ui, :multiline_class, [extra <> " "], extra)

  defp sub_field_class(ui, :json, extra),
    do: adapter_class(ui, :multiline_class, [extra <> " "], extra)

  defp sub_field_class(ui, _type, extra) do
    case adapter_class(ui, :input_class, [false], nil) do
      nil -> extra
      base -> base <> " " <> extra
    end
  end

  defp adapter_class(ui, fun, args, fallback) do
    case MishkaGervaz.Helpers.exports?(ui, fun, length(args)) do
      true -> apply(ui, fun, args)
      false -> fallback
    end
  end

  defp sub_field_base(assigns) do
    base = %{
      __changed__: nil,
      module: assigns.ui,
      name: assigns.input_name,
      id: assigns.input_id,
      value: assigns.input_value,
      disabled: assigns.sf.readonly,
      readonly: assigns.sf.readonly
    }

    case sub_field_class(assigns.ui, assigns.sf.type, assigns.sf.class) do
      nil -> base
      class -> Map.put(base, :class, class)
    end
  end

  @doc false
  def compute_sub_field_errors(entry, nested_fields, error_mode)

  def compute_sub_field_errors(_entry, _nested_fields, false), do: %{}

  def compute_sub_field_errors(entry, nested_fields, true) do
    compute_sub_field_errors(entry, nested_fields, %{required: true, type: true})
  end

  def compute_sub_field_errors(entry, nested_fields, %{} = mode) do
    show_required = Map.get(mode, :required, false)
    show_type = Map.get(mode, :type, false)

    if not show_required and not show_type do
      %{}
    else
      Map.new(nested_fields, fn sf ->
        info = extract_sub_field_info(sf)
        value = get_entry_value(entry, info.name)
        {info.name, validate_sub_field_value(value, info, show_required, show_type)}
      end)
      |> Enum.reject(fn {_k, v} -> v == [] end)
      |> Map.new()
    end
  end

  @doc false
  def validate_sub_field_value(value, sf, show_required \\ true, show_type \\ true),
    do: required_error(value, sf, show_required) ++ type_error(value, sf, show_type)

  defp required_error(value, %{required: true}, true) do
    case blank_sub_value?(value) do
      true -> ["is required"]
      false -> []
    end
  end

  defp required_error(_value, _sf, _show_required), do: []

  defp type_error(nil, _sf, _show_type), do: []
  defp type_error(_value, _sf, false), do: []

  defp type_error(value, sf, true) do
    type_mod = MishkaGervaz.Form.Types.Field.get_or_passthrough(sf.type)

    with false <- blank_sub_value?(value),
         true <- is_atom(type_mod) and not is_nil(type_mod),
         true <-
           Map.get(sf, :custom_validate?, MishkaGervaz.Helpers.exports?(type_mod, :validate, 2)),
         {:error, message} <- type_mod.validate(value, %{ash_type: Map.get(sf, :ash_type)}) do
      [message]
    else
      _nothing_to_say -> []
    end
  end

  @doc false
  def blank_sub_value?(nil), do: true
  def blank_sub_value?(""), do: true

  def blank_sub_value?(v) when is_binary(v) do
    String.trim(v) == ""
  end

  def blank_sub_value?(_), do: false

  defp get_map_entries(field_name, form) do
    params = AshPhoenix.Form.params(form.source)
    field_key = to_string(field_name)
    key_exists? = Map.has_key?(params, field_key)

    entries =
      case Map.get(params, field_key) do
        map when is_map(map) and not is_struct(map) ->
          map
          |> Enum.map(fn {k, v} -> {to_integer_safe(k), v} end)
          |> Enum.sort_by(&elem(&1, 0))

        list when is_list(list) ->
          list |> Enum.with_index() |> Enum.map(fn {v, i} -> {i, v} end)

        _ ->
          []
      end

    if entries == [] and not key_exists? do
      case Map.get(form.data || %{}, field_name) do
        list when is_list(list) and list != [] ->
          list |> Enum.with_index() |> Enum.map(fn {v, i} -> {i, v} end)

        _ ->
          []
      end
    else
      entries
    end
  end

  defp to_integer_safe(v) when is_integer(v), do: v

  defp to_integer_safe(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp to_integer_safe(_), do: 0

  defp get_entry_value(entry, name) when is_map(entry) do
    Map.get(entry, name) || Map.get(entry, to_string(name))
  end

  defp get_entry_value(_, _), do: nil

  defp encode_json_value(v) when is_map(v) or is_list(v), do: Jason.encode!(v, pretty: true)
  defp encode_json_value(v) when is_binary(v), do: v
  defp encode_json_value(nil), do: ""
  defp encode_json_value(v), do: inspect(v)

  defp extract_sub_field_info(sub_field),
    do: extract_sub_field_info(sub_field, false, nil)

  defp extract_sub_field_info(sub_field, parent_readonly, _state) when is_atom(sub_field) do
    label = Phoenix.Naming.humanize(sub_field)

    %{
      name: sub_field,
      label: label,
      type: :text,
      ash_type: nil,
      required: false,
      placeholder: label,
      options: nil,
      rows: nil,
      class: nil,
      span: nil,
      add_label: nil,
      remove_label: nil,
      visible: true,
      readonly: parent_readonly
    }
  end

  defp extract_sub_field_info(sf, parent_readonly, state) when is_map(sf) do
    name = sub_field_name(sf)
    label = resolve_callable(Map.get(sf, :label)) || Phoenix.Naming.humanize(name)
    type = Map.get(sf, :type, :text)

    %{
      name: name,
      label: label,
      type: type,
      ash_type: Map.get(sf, :ash_type),
      required: Map.get(sf, :required, false),
      placeholder: resolve_callable(Map.get(sf, :placeholder)) || label,
      options: Map.get(sf, :options),
      rows: Map.get(sf, :rows),
      class: Map.get(sf, :class),
      span: Map.get(sf, :span) || auto_span(type),
      add_label: resolve_callable(Map.get(sf, :add_label)),
      remove_label: resolve_callable(Map.get(sf, :remove_label)),
      visible: Map.get(sf, :visible, true),
      readonly: parent_readonly or resolve_sub_readonly(Map.get(sf, :readonly, false), state)
    }
  end

  # A sub-field's name: `:name` when the map carries one, `:field` otherwise.
  defp sub_field_name(%{name: name}), do: name
  defp sub_field_name(sf), do: Map.get(sf, :field, Map.get(sf, :name))

  defp auto_span(:textarea), do: 2
  defp auto_span(:json), do: 2
  defp auto_span(:key_list), do: 2
  defp auto_span(_), do: nil

  defp resolve_callable(f) when is_function(f, 0), do: f.()
  defp resolve_callable(v), do: v

  defp resolve_field_options(field) do
    MishkaGervaz.Helpers.resolve_options(Map.get(field, :options))
  end

  defp evaluate_readonly(%{readonly: f}, state) when is_function(f, 1), do: f.(state)
  defp evaluate_readonly(%{readonly: val}, _state) when is_boolean(val), do: val
  defp evaluate_readonly(_, _state), do: false

  defp resolve_sub_readonly(f, state) when is_function(f, 1) and not is_nil(state), do: f.(state)
  defp resolve_sub_readonly(val, _state) when is_boolean(val), do: val
  defp resolve_sub_readonly(_, _state), do: false

  defp evaluate_button_disabled(button, state) do
    case button[:disabled] do
      f when is_function(f, 1) -> f.(state)
      val when is_boolean(val) -> val
      _ -> false
    end
  end

  defp evaluate_button_visible(button, state) do
    case button[:visible] do
      f when is_function(f, 1) -> f.(state)
      val when is_boolean(val) -> val
      _ -> true
    end
  end

  defp evaluate_button_active(button, state) do
    case button[:active] do
      f when is_function(f, 1) -> f.(state)
      val when is_boolean(val) -> val
      _ -> true
    end
  end

  defp evaluate_button_restricted(button, state) do
    case button[:restricted] do
      f when is_function(f, 1) -> f.(state)
      true -> not state.master_user?
      _ -> false
    end
  end

  defp resolve_nested_label(field, key, default) do
    ui_val = get_in_map(field, [:ui, key])
    field_val = Map.get(field, key)
    resolve_label(ui_val) || resolve_label(field_val) || default
  end

  defp render_upload_by_style(assigns) do
    has_new_entries = assigns[:upload] && assigns.upload.entries != []
    show_existing = assigns.existing_files != [] && !has_new_entries

    assigns =
      assigns
      |> assign(:has_new_entries, has_new_entries)
      |> assign(:show_existing, show_existing)

    ~H"""
    <div class="space-y-3">
      <%= if @show_existing do %>
        {render_existing_files(assigns)}
      <% end %>

      <%= case @style do %>
        <% :dropzone -> %>
          <.dynamic_component
            :if={@upload}
            module={@ui}
            function={:upload_dropzone}
            upload_ref={@upload.ref}
            accept={@upload_config[:accept]}
            max_entries={@upload_config[:max_entries] || 1}
          >
            {render_live_file_input(assigns, "sr-only")}
          </.dynamic_component>
        <% :file_input -> %>
          <.dynamic_component
            :if={@upload}
            module={@ui}
            function={:upload_file_input}
            accept={@upload_config[:accept]}
            max_entries={@upload_config[:max_entries] || 1}
          >
            {render_live_file_input(assigns, nil)}
          </.dynamic_component>
        <% :custom -> %>
          <%= if @upload do %>
            {render_live_file_input(assigns, nil)}
          <% end %>
      <% end %>

      <%= if @upload do %>
        {render_upload_entries(assigns)}
      <% end %>

      <%= if @upload do %>
        {render_upload_errors(assigns)}
      <% end %>
    </div>
    """
  end

  defp render_live_file_input(assigns, class) do
    assigns = assign(assigns, :input_class, class)

    ~H"""
    <.live_file_input upload={@upload} class={@input_class} />
    """
  end

  defp render_upload_entries(assigns) do
    ~H"""
    <div :if={@upload.entries != []} class="space-y-2">
      <%= for entry <- @upload.entries do %>
        <div class="flex items-center gap-3 rounded-[12px] border border-[#ecebe6] bg-white p-[10px] shadow-[0_1px_2px_rgba(30,28,24,0.04)]">
          <div class="size-11 flex-none overflow-hidden rounded-[9px] bg-[#f4f3ee]">
            <%= if String.starts_with?(entry.client_type, "image/") do %>
              <.live_img_preview entry={entry} class="size-full object-cover" />
            <% else %>
              <div class="grid size-full place-items-center text-[#8a877f]">
                <span class="hero-document size-5"></span>
              </div>
            <% end %>
          </div>

          <div class="min-w-0 flex-1">
            <p class="truncate text-[12.5px] font-semibold text-[#1b1a18]">{entry.client_name}</p>
            <%= if entry.progress < 100 do %>
              <div class="mt-[7px] h-[5px] w-full overflow-hidden rounded-full bg-[#efeee9]">
                <div
                  class="h-full rounded-full bg-[#5b57d6] transition-all duration-300"
                  style={"width: #{entry.progress}%"}
                />
              </div>
              <p class="mt-[5px] font-['Space_Grotesk'] text-[10.5px] font-semibold text-[#8a877f]">
                {entry.progress}%
              </p>
            <% else %>
              <p class="mt-[3px] font-['Space_Grotesk'] text-[11px] font-medium text-[#8a877f]">
                {format_filesize(entry.client_size)}
              </p>
            <% end %>
          </div>

          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-key={@upload_config.name}
            phx-value-ref={entry.ref}
            phx-target={@myself}
            class="grid size-[30px] flex-none place-items-center rounded-[9px] border border-[#ecebe6] bg-white text-[#8a877f] transition-colors hover:border-[#f3ddd9] hover:bg-[#fdf4f3] hover:text-[#c0392b]"
            title="Cancel upload"
          >
            <span class="hero-x-mark size-[15px]"></span>
          </button>
        </div>

        <div
          :for={err <- upload_errors(@upload, entry)}
          class="text-[11.5px] font-medium text-[#c0392b]"
        >
          {UploadHelpers.upload_error_to_string(err)}
        </div>
      <% end %>
    </div>
    """
  end

  defp render_upload_errors(assigns) do
    ~H"""
    <div
      :for={err <- upload_errors(@upload)}
      class="flex items-center gap-1 text-[11.5px] font-medium text-[#c0392b]"
    >
      <span class="hero-exclamation-circle w-4 h-4 shrink-0"></span>
      {UploadHelpers.upload_error_to_string(err)}
    </div>
    """
  end

  defp render_existing_files(assigns) do
    ~H"""
    <div class="space-y-2">
      <.dynamic_component
        :for={file <- @existing_files}
        module={@ui}
        function={:upload_existing_file}
        file={file}
        filename={file[:filename] || file[:name] || "File"}
        file_id={file[:id] || file[:filename] || file[:name]}
        upload_name={@upload_config.name}
        phx_target={@myself}
      />
    </div>
    """
  end

  defp last_step?(assigns) do
    steps = assigns.static.steps
    current = assigns.state.current_step

    case steps do
      [] -> true
      steps -> List.last(steps).name == current
    end
  end

  defp put_present(assigns, _key, nil), do: assigns
  defp put_present(assigns, key, value), do: assign(assigns, key, value)

  defp get_in_map(map, keys) do
    Enum.reduce_while(keys, map, fn key, acc ->
      case acc do
        %{^key => value} -> {:cont, value}
        _ -> {:halt, nil}
      end
    end)
  end

  defp resolve_js_hook(assigns, hook_name) do
    case assigns.static.hooks do
      %{js: %{^hook_name => func}} when is_function(func, 0) ->
        func.()

      %{js: %{^hook_name => func}} when is_function(func, 1) ->
        func.(Map.get(assigns, :record_id))

      _ ->
        %JS{}
    end
  end
end

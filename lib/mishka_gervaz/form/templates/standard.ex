defmodule MishkaGervaz.Form.Templates.Standard do
  @moduledoc """
  Default form template for MishkaGervaz.

  Renders forms using the configured UI adapter for component styling.
  Supports standard, wizard, and tabs layout modes.
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
            <%= if @state.form_errors != [] do %>
              <div class="mb-4 rounded-md bg-red-50 p-4">
                <div class="flex">
                  <div class="text-sm text-red-700">
                    <p :for={err <- @state.form_errors}>{err}</p>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @state.static.layout_mode == :standard do %>
              {render_groups(assigns)}
            <% else %>
              {render_current_step_groups(assigns)}
            <% end %>

            {render_uploads_section(assigns)}
            {render_submit(assigns)}
          </.form>
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
      group_ui = Map.get(group, :ui) || %{}
      group_class = Map.get(group_ui, :class)

      assigns =
        assigns
        |> assign(:group_label, Map.get(group, :resolved_label))
        |> assign(:group_fields, group_fields)
        |> assign(:group_columns, Map.get(group_ui, :columns))
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
      # No explicit groups — render all fields in a flat layout
      render_group_fields(assigns, assigns.static.fields, nil)
    else
      visible_groups = Enum.filter(groups, &accessible?(&1, assigns.state))
      assigns = assign(assigns, :all_groups, visible_groups)

      ~H"""
      <div>
        <%= for group <- @all_groups do %>
          <% group_assigns = assign(assigns, :group, group) %>
          {render_group(group_assigns)}
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
        {render_group(ga)}
      <% end %>
    </div>
    """
  end

  defp render_group_fields(assigns, fields, group_columns) do
    columns = group_columns || assigns.static.layout_columns
    mode = assigns.state.mode

    visible_fields =
      Enum.filter(fields, fn field ->
        accessible?(field, assigns.state) and show_on_mode?(field, mode)
      end)

    col_class =
      if group_columns do
        group_col_class(group_columns)
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
        {render_field(fa)}
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

  defp nested_span_class(nil), do: nil
  defp nested_span_class(1), do: "col-span-1"
  defp nested_span_class(2), do: "col-span-2"
  defp nested_span_class(3), do: "col-span-3"
  defp nested_span_class(4), do: "col-span-4"
  defp nested_span_class(_), do: nil

  defp render_submit(assigns) do
    submit = assigns.static.submit
    mode = assigns.state.mode
    state = assigns.state
    layout_mode = assigns.static.layout_mode

    submit_button = if mode == :create, do: submit[:create], else: submit[:update]
    cancel_button = submit[:cancel]

    show_submit =
      submit_button != nil and
        evaluate_button_visible(submit_button, state) and
        not evaluate_button_restricted(submit_button, state)

    show_cancel =
      cancel_button != nil and
        (state.mode == :update or state.dirty?) and
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
      |> assign(:cancel_label, cancel_label)
      |> assign(:show_submit, show_submit)
      |> assign(:show_cancel, show_cancel)
      |> assign(:submit_disabled, submit_disabled)
      |> assign(:cancel_disabled, cancel_disabled)
      |> assign(:show_step_nav, layout_mode in [:wizard, :tabs])
      |> assign(:ui, assigns.static.ui_adapter)
      |> assign(:cancel_js, cancel_js)

    ~H"""
    <div class="mt-6 flex items-center justify-between">
      <div class="flex gap-2">
        <%= if @show_step_nav do %>
          <.dynamic_component
            module={@ui}
            function={:step_navigation}
            current_step={@state.current_step}
            steps={@static.steps}
            step_states={@state.step_states}
            myself={@myself}
          />
        <% end %>
      </div>

      <div class="flex gap-2">
        <%= if @show_cancel do %>
          <.dynamic_component
            module={@ui}
            function={:button}
            label={@cancel_label}
            variant={:secondary}
            type="button"
            disabled={@cancel_disabled}
            phx_click={@cancel_js}
            phx_target={@myself}
          />
        <% end %>

        <%= if @show_submit and (not @show_step_nav or last_step?(assigns)) do %>
          <button
            type="submit"
            disabled={@submit_disabled}
            class={[
              "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white",
              if(@submit_disabled,
                do: "bg-gray-400 cursor-not-allowed",
                else:
                  "bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              )
            ]}
          >
            {@submit_label}
          </button>
        <% end %>
      </div>
    </div>
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
        <div class={[
          "px-3 py-2 text-sm border rounded cursor-not-allowed flex items-center gap-2",
          if(@is_loading,
            do: "bg-blue-50 border-blue-200 text-blue-500",
            else: "bg-gray-100 border-gray-200 text-gray-400"
          )
        ]}>
          <span
            :if={@is_loading}
            class="w-4 h-4 border-2 border-blue-200 border-t-blue-500 rounded-full animate-spin shrink-0"
          />
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

    base =
      assigns
      |> assign(:field, form_field)
      |> assign(:name, form_field.name)
      |> assign(:id, form_field.id)
      |> assign(:value, Phoenix.HTML.Form.input_value(assigns.state.form, field.name))
      |> assign(:placeholder, resolve_label(get_in_map(field, [:ui, :placeholder])))
      |> assign(:disabled, evaluate_readonly(field, assigns.state))
      |> assign(:module, ui)
      |> assign(:phx_debounce, debounce)

    case type do
      :password ->
        base
        |> assign(:function, :password_input)
        |> assign(:autocomplete, get_in_map(field, [:ui, :autocomplete]) || "new-password")
        |> dynamic_component()

      t when t in [:text, :email, :url, :tel, :hidden] ->
        base
        |> assign(:function, :text_input)
        |> assign(:type, to_string(t))
        |> dynamic_component()

      :number ->
        base |> assign(:function, :number_input) |> dynamic_component()

      :textarea ->
        base |> assign(:function, :textarea) |> dynamic_component()

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
        base |> assign(:function, :date_input) |> dynamic_component()

      :datetime ->
        base |> assign(:function, :datetime_input) |> dynamic_component()

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
    |> assign(:field_name, to_string(field.name))
    |> assign(:disabled, evaluate_readonly(field, assigns.state))
    |> assign(:add_label, resolve_label(field.add_label) || "+ Add")
    |> assign(:remove_label, resolve_label(field.remove_label) || "Remove")
    |> assign(:placeholder, resolve_label(get_in_map(field, [:ui, :placeholder])))
    |> assign(:target, assigns[:myself])
    |> dynamic_component()
  end

  defp render_nested_input(ui, field, form_field, assigns) do
    nested_source = get_in_map(field, [:ui, :extra, :nested_source]) || :embedded

    if nested_source == :constrained_map do
      render_constrained_map_nested(field, assigns)
    else
      render_embedded_nested(ui, field, form_field, assigns)
    end
  end

  defp render_embedded_nested(_ui, field, _form_field, assigns) do
    nested_fields = Map.get(field, :nested_fields, [])
    form_path = assigns.state.form.name <> "[#{field.name}]"
    nested_mode = get_in_map(field, [:ui, :extra, :nested_mode]) || :array
    parent_readonly = evaluate_readonly(field, assigns.state)

    assigns =
      assigns
      |> assign(:nested_field, field)
      |> assign(:nested_fields, nested_fields)
      |> assign(:form_path, form_path)
      |> assign(:nested_mode, nested_mode)
      |> assign(:parent_readonly, parent_readonly)
      |> assign(:add_label, resolve_nested_label(field, :add_label, "+ Add"))
      |> assign(:remove_label, resolve_nested_label(field, :remove_label, "Remove"))
      |> assign(:target, assigns[:myself])

    ~H"""
    <div class="space-y-3">
      <.inputs_for :let={nested_form} field={@state.form[@nested_field.name]}>
        <div class="border rounded bg-gray-50 p-3">
          <div class="flex justify-between items-start mb-2">
            <span class="text-sm font-medium text-gray-600">
              <%= if @nested_mode == :array do %>
                {Phoenix.Naming.humanize(@nested_field.name)} {nested_form.index + 1}
              <% else %>
                {Phoenix.Naming.humanize(@nested_field.name)}
              <% end %>
            </span>
            <%= if @nested_mode == :array and not @parent_readonly do %>
              <button
                type="button"
                phx-click="remove_nested"
                phx-value-path={nested_form.name}
                phx-target={@target}
                class="text-red-600 hover:text-red-800 text-sm"
              >
                {@remove_label}
              </button>
            <% end %>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <%= for sub_field <- @nested_fields do %>
              <% sf = extract_sub_field_info(sub_field, @parent_readonly, @state) %>
              {render_nested_sub_field(assigns, nested_form, sf)}
            <% end %>
          </div>
        </div>
      </.inputs_for>

      <%= if @nested_mode == :array and not @parent_readonly do %>
        <button
          type="button"
          phx-click="add_nested"
          phx-value-path={@form_path}
          phx-target={@target}
          class="w-full py-2 px-4 border border-dashed border-gray-300 rounded-md text-sm text-gray-600 hover:border-gray-400 hover:text-gray-700"
        >
          {@add_label}
        </button>
      <% end %>
    </div>
    """
  end

  defp render_constrained_map_nested(field, assigns) do
    nested_fields = Map.get(field, :nested_fields, [])
    nested_mode = get_in_map(field, [:ui, :extra, :nested_mode]) || :array
    entries = get_map_entries(field.name, assigns.state.form)
    form_name = assigns.state.form.name
    parent_readonly = evaluate_readonly(field, assigns.state)

    submitted_once =
      assigns.state.form != nil and assigns.state.form.source != nil and
        assigns.state.form.source.submitted_once?

    error_mode = %{required: submitted_once, type: true}

    assigns =
      assigns
      |> assign(:nested_field, field)
      |> assign(:nested_fields, nested_fields)
      |> assign(:nested_mode, nested_mode)
      |> assign(:parent_readonly, parent_readonly)
      |> assign(:entries, entries)
      |> assign(:form_name, form_name)
      |> assign(:error_mode, error_mode)
      |> assign(:add_label, resolve_nested_label(field, :add_label, "+ Add"))
      |> assign(:remove_label, resolve_nested_label(field, :remove_label, "Remove"))
      |> assign(:target, assigns[:myself])

    ~H"""
    <div class="space-y-3">
      <%= for {idx, entry} <- @entries do %>
        <% entry_errors = compute_sub_field_errors(entry, @nested_fields, @error_mode) %>
        <div class="border rounded bg-gray-50 p-3">
          <div class="flex justify-between items-start mb-2">
            <span class="text-sm font-medium text-gray-600">
              {Phoenix.Naming.humanize(@nested_field.name)} {idx + 1}
            </span>
            <%= if @nested_mode == :array and not @parent_readonly do %>
              <button
                type="button"
                phx-click="remove_nested"
                phx-value-field={to_string(@nested_field.name)}
                phx-value-index={to_string(idx)}
                phx-target={@target}
                class="text-red-600 hover:text-red-800 text-sm"
              >
                {@remove_label}
              </button>
            <% end %>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <%= for sub_field <- @nested_fields do %>
              <% sf = extract_sub_field_info(sub_field, @parent_readonly, @state) %>
              <% sf_errors = Map.get(entry_errors, sf.name, []) %>
              {render_constrained_sub_field(assigns, sf, idx, entry, sf_errors)}
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @nested_mode == :array and not @parent_readonly do %>
        <button
          type="button"
          phx-click="add_nested"
          phx-value-field={to_string(@nested_field.name)}
          phx-target={@target}
          class="w-full py-2 px-4 border border-dashed border-gray-300 rounded-md text-sm text-gray-600 hover:border-gray-400 hover:text-gray-700"
        >
          {@add_label}
        </button>
      <% end %>
    </div>
    """
  end

  defp render_constrained_sub_field(assigns, sf, idx, entry, errors) do
    field_name = assigns.nested_field.name
    form_name = assigns.form_name
    name = "#{form_name}[#{field_name}][#{idx}][#{sf.name}]"
    id = "#{form_name}_#{field_name}_#{idx}_#{sf.name}"
    value = get_entry_value(entry, sf.name)

    assigns =
      assigns
      |> assign(:sf, sf)
      |> assign(:input_name, name)
      |> assign(:input_id, id)
      |> assign(:input_value, value)
      |> assign(:sub_errors, errors)

    if not sf.visible do
      ~H""
    else
      base_class =
        "block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"

      error_ring = if(errors != [], do: " ring-1 ring-red-500", else: "")

      input_class =
        if sf.class do
          "#{base_class} #{sf.class}#{error_ring}"
        else
          "#{base_class}#{error_ring}"
        end

      assigns =
        assigns
        |> assign(:input_class, input_class)

      ~H"""
      <div class={nested_span_class(@sf.span)}>
        <label class="block text-xs font-medium text-gray-500 mb-1">
          {@sf.label}
          <%= if @sf.required do %>
            <span class="text-red-500">*</span>
          <% end %>
        </label>
        <%= case @sf.type do %>
          <% :textarea -> %>
            <textarea
              name={@input_name}
              id={@input_id}
              placeholder={@sf.placeholder}
              rows={@sf.rows || 3}
              disabled={@sf.readonly}
              class={@input_class}
            >{@input_value}</textarea>
          <% t when t in [:checkbox, :toggle] -> %>
            <input type="hidden" name={@input_name} value="false" />
            <input
              type="checkbox"
              name={@input_name}
              id={@input_id}
              value="true"
              checked={@input_value in [true, "true"]}
              disabled={@sf.readonly}
              class="rounded border-gray-300"
            />
          <% :number -> %>
            <input
              type="number"
              name={@input_name}
              id={@input_id}
              value={@input_value}
              placeholder={@sf.placeholder}
              disabled={@sf.readonly}
              class={@input_class}
            />
          <% :date -> %>
            <input
              type="date"
              name={@input_name}
              id={@input_id}
              value={@input_value}
              disabled={@sf.readonly}
              class={@input_class}
            />
          <% :datetime -> %>
            <input
              type="datetime-local"
              name={@input_name}
              id={@input_id}
              value={@input_value}
              disabled={@sf.readonly}
              class={@input_class}
            />
          <% :json -> %>
            <textarea
              name={@input_name}
              id={@input_id}
              placeholder={@sf.placeholder}
              rows={@sf.rows || 3}
              disabled={@sf.readonly}
              class={@input_class}
            >{encode_json_value(@input_value)}</textarea>
          <% :select -> %>
            <select
              name={@input_name}
              id={@input_id}
              disabled={@sf.readonly}
              class={@input_class}
            >
              <option value="">{@sf.placeholder}</option>
              <%= for opt <- @sf.options || [] do %>
                <% {opt_label, opt_val} = if is_tuple(opt), do: opt, else: {opt, opt} %>
                <option value={opt_val} selected={to_string(opt_val) == to_string(@input_value)}>
                  {opt_label}
                </option>
              <% end %>
            </select>
          <% _ -> %>
            <input
              type="text"
              name={@input_name}
              id={@input_id}
              value={@input_value}
              placeholder={@sf.placeholder}
              disabled={@sf.readonly}
              class={@input_class}
            />
        <% end %>
        <%= if @sub_errors != [] do %>
          <div class="mt-1">
            <p :for={err <- @sub_errors} class="text-sm text-red-600">{err}</p>
          </div>
        <% end %>
      </div>
      """
    end
  end

  defp render_nested_sub_field(assigns, nested_form, sf) do
    assigns =
      assigns
      |> assign(:sf, sf)
      |> assign(:nf, nested_form)

    if not sf.visible do
      ~H""
    else
      base_class =
        "block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"

      input_class = if(sf.class, do: "#{base_class} #{sf.class}", else: base_class)
      assigns = assign(assigns, :input_class, input_class)

      ~H"""
      <div class={nested_span_class(@sf.span)}>
        <label class="block text-xs font-medium text-gray-500 mb-1">
          {@sf.label}
          <%= if @sf.required do %>
            <span class="text-red-500">*</span>
          <% end %>
        </label>
        <%= case @sf.type do %>
          <% :textarea -> %>
            <textarea
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              placeholder={@sf.placeholder}
              rows={@sf.rows || 3}
              disabled={@sf.readonly}
              class={@input_class}
            >{@nf[@sf.name].value}</textarea>
          <% t when t in [:checkbox, :toggle] -> %>
            <input type="hidden" name={@nf[@sf.name].name} value="false" />
            <input
              type="checkbox"
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              value="true"
              checked={@nf[@sf.name].value in [true, "true"]}
              disabled={@sf.readonly}
              class="rounded border-gray-300"
            />
          <% :number -> %>
            <input
              type="number"
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              value={@nf[@sf.name].value}
              placeholder={@sf.placeholder}
              disabled={@sf.readonly}
              class={@input_class}
            />
          <% :date -> %>
            <input
              type="date"
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              value={@nf[@sf.name].value}
              disabled={@sf.readonly}
              class={@input_class}
            />
          <% :datetime -> %>
            <input
              type="datetime-local"
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              value={@nf[@sf.name].value}
              disabled={@sf.readonly}
              class={@input_class}
            />
          <% :hidden -> %>
            <input
              type="hidden"
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              value={@nf[@sf.name].value}
            />
          <% :select -> %>
            <select
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              disabled={@sf.readonly}
              class={@input_class}
            >
              <option value="">{@sf.placeholder}</option>
              <%= for opt <- @sf.options || [] do %>
                <% {opt_label, opt_val} = if is_tuple(opt), do: opt, else: {opt, opt} %>
                <option
                  value={opt_val}
                  selected={to_string(opt_val) == to_string(@nf[@sf.name].value)}
                >
                  {opt_label}
                </option>
              <% end %>
            </select>
          <% _ -> %>
            <input
              type="text"
              name={@nf[@sf.name].name}
              id={@nf[@sf.name].id}
              value={@nf[@sf.name].value}
              placeholder={@sf.placeholder}
              disabled={@sf.readonly}
              class={@input_class}
            />
        <% end %>
      </div>
      """
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
  def validate_sub_field_value(value, sf, show_required \\ true, show_type \\ true) do
    errors = []

    errors =
      if show_required && sf.required && blank_sub_value?(value) do
        ["is required" | errors]
      else
        errors
      end

    errors =
      if show_type && not is_nil(value) && not blank_sub_value?(value) do
        type_mod = MishkaGervaz.Form.Types.Field.get_or_passthrough(sf.type)
        config = %{ash_type: Map.get(sf, :ash_type)}

        with true <- is_atom(type_mod) and type_mod != nil,
             {:module, _} <- Code.ensure_loaded(type_mod),
             true <- function_exported?(type_mod, :validate, 2),
             {:error, msg} <- type_mod.validate(value, config) do
          [msg | errors]
        else
          _ -> errors
        end
      else
        errors
      end

    Enum.reverse(errors)
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
      visible: true,
      readonly: parent_readonly
    }
  end

  defp extract_sub_field_info(%{name: name} = sf, parent_readonly, state) do
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
      visible: Map.get(sf, :visible, true),
      readonly: parent_readonly or resolve_sub_readonly(Map.get(sf, :readonly, false), state)
    }
  end

  defp extract_sub_field_info(sf, parent_readonly, state) when is_map(sf) do
    name = Map.get(sf, :field, Map.get(sf, :name))
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
      visible: Map.get(sf, :visible, true),
      readonly: parent_readonly or resolve_sub_readonly(Map.get(sf, :readonly, false), state)
    }
  end

  defp auto_span(:textarea), do: 2
  defp auto_span(:json), do: 2
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
          <%= if @upload do %>
            <.dynamic_component
              module={@ui}
              function={:upload_dropzone}
              upload_ref={@upload.ref}
              accept={@upload_config[:accept]}
              max_entries={@upload_config[:max_entries] || 1}
            >
              {render_live_file_input(assigns, "sr-only")}
            </.dynamic_component>
          <% end %>
        <% :file_input -> %>
          <%= if @upload do %>
            <.dynamic_component
              module={@ui}
              function={:upload_file_input}
              accept={@upload_config[:accept]}
              max_entries={@upload_config[:max_entries] || 1}
            >
              {render_live_file_input(assigns, nil)}
            </.dynamic_component>
          <% end %>
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
        <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg border">
          <%!-- Thumbnail / preview --%>
          <div class="w-12 h-12 bg-gray-200 rounded overflow-hidden flex-shrink-0">
            <%= if String.starts_with?(entry.client_type, "image/") do %>
              <.live_img_preview entry={entry} class="w-full h-full object-cover" />
            <% else %>
              <div class="flex items-center justify-center w-full h-full">
                <span class="hero-document w-6 h-6 text-gray-400"></span>
              </div>
            <% end %>
          </div>

          <%!-- File info + progress --%>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">{entry.client_name}</p>
            <%= if entry.progress < 100 do %>
              <div class="w-full bg-gray-200 rounded-full h-1.5 mt-1">
                <div
                  class="bg-blue-600 h-1.5 rounded-full transition-all duration-300"
                  style={"width: #{entry.progress}%"}
                />
              </div>
              <p class="text-xs text-gray-500 mt-0.5">{entry.progress}%</p>
            <% else %>
              <p class="text-xs text-gray-500">
                {format_filesize(entry.client_size)}
              </p>
            <% end %>
          </div>

          <%!-- Cancel button --%>
          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-key={@upload_config.name}
            phx-value-ref={entry.ref}
            phx-target={@myself}
            class="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors flex-shrink-0"
            title="Cancel upload"
          >
            <span class="hero-x-mark w-5 h-5"></span>
          </button>
        </div>

        <div :for={err <- upload_errors(@upload, entry)} class="text-sm text-red-600">
          {UploadHelpers.upload_error_to_string(err)}
        </div>
      <% end %>
    </div>
    """
  end

  defp render_upload_errors(assigns) do
    ~H"""
    <div :for={err <- upload_errors(@upload)} class="text-sm text-red-600 flex items-center gap-1">
      <span class="hero-exclamation-circle w-4 h-4 shrink-0"></span>
      {UploadHelpers.upload_error_to_string(err)}
    </div>
    """
  end

  defp render_existing_files(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= for file <- @existing_files do %>
        <.dynamic_component
          module={@ui}
          function={:upload_existing_file}
          file={file}
          filename={file[:filename] || file[:name] || "File"}
          file_id={file[:id] || file[:filename] || file[:name]}
          upload_name={@upload_config.name}
          phx_target={@myself}
        />
      <% end %>
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

defmodule MishkaGervaz.Form.Templates.Standard do
  @moduledoc """
  Default form template for MishkaGervaz.

  Renders forms using the configured UI adapter for component styling.
  Supports standard, wizard, and tabs layout modes.
  """

  @behaviour MishkaGervaz.Form.Behaviours.Template
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  import MishkaGervaz.Helpers, only: [get_ui_label: 1]
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
    <div id={@static.id <> "-form-wrapper"} phx-mounted={@init_js}>
      <%= if @state.loading == :loaded and @state.form do %>
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
          <%= if @state.static.layout_mode == :standard do %>
            {render_groups(assigns)}
          <% else %>
            {render_current_step_groups(assigns)}
          <% end %>

          {render_submit(assigns)}
        </.form>
      <% else %>
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
      {@ui.spinner(%{size: :lg})}
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

    assigns =
      assigns
      |> assign(:group_label, Map.get(group, :resolved_label, ""))
      |> assign(:group_fields, Map.get(group, :resolved_fields, []))
      |> assign(:ui, assigns.static.ui_adapter)
      |> assign(:collapsible, Map.get(group, :collapsible, false))

    ~H"""
    <div>
      {@ui.field_group(%{
        label: @group_label,
        collapsible: @collapsible,
        open: true,
        inner_block: render_group_fields(assigns, @group_fields)
      })}
    </div>
    """
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
      {@ui.step_indicator(%{steps: @step_data, current: @current_step})}
    </div>
    """
  end

  defp render_groups(assigns) do
    assigns = assign(assigns, :all_groups, assigns.static.groups)

    ~H"""
    <div>
      <%= for group <- @all_groups do %>
        <% group_assigns = assign(assigns, :group, group) %>
        {render_group(group_assigns)}
      <% end %>
    </div>
    """
  end

  defp render_current_step_groups(assigns) do
    current_step = assigns.state.current_step
    steps = assigns.static.steps
    groups = assigns.static.groups

    step_groups =
      case Enum.find(steps, &(&1.name == current_step)) do
        %{groups: group_names} when is_list(group_names) ->
          Enum.filter(groups, &(&1.name in group_names))

        _ ->
          groups
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

  defp render_group_fields(assigns, fields) do
    columns = assigns.static.layout_columns

    col_class =
      case columns do
        1 -> "grid grid-cols-1 gap-4"
        2 -> "grid grid-cols-1 md:grid-cols-2 gap-4"
        3 -> "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
        4 -> "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4"
        _ -> "grid grid-cols-1 gap-4"
      end

    assigns =
      assigns
      |> assign(:col_class, col_class)
      |> assign(:render_fields, fields)

    ~H"""
    <div class={@col_class}>
      <%= for field <- @render_fields do %>
        <% fa = assign(assigns, :field, field) %>
        {render_field(fa)}
      <% end %>
    </div>
    """
  end

  defp render_submit(assigns) do
    submit = assigns.static.submit
    mode = assigns.state.mode
    layout_mode = assigns.static.layout_mode

    submit_label =
      if mode == :create,
        do: Map.get(submit, :create_label, "Create"),
        else: Map.get(submit, :update_label, "Update")

    cancel_js =
      assigns
      |> resolve_js_hook(:on_cancel)
      |> JS.push("cancel", target: assigns.myself)

    assigns =
      assigns
      |> assign(:submit_label, submit_label)
      |> assign(:cancel_label, Map.get(submit, :cancel_label, "Cancel"))
      |> assign(:show_cancel, Map.get(submit, :show_cancel, true))
      |> assign(:show_step_nav, layout_mode in [:wizard, :tabs])
      |> assign(:ui, assigns.static.ui_adapter)
      |> assign(:cancel_js, cancel_js)

    ~H"""
    <div class="mt-6 flex items-center justify-between">
      <div class="flex gap-2">
        <%= if @show_step_nav do %>
          {@ui.step_navigation(%{
            current_step: @state.current_step,
            steps: @static.steps,
            step_states: @state.step_states,
            myself: @myself
          })}
        <% end %>
      </div>

      <div class="flex gap-2">
        <%= if @show_cancel do %>
          {@ui.button(%{
            label: @cancel_label,
            variant: :secondary,
            phx_click: @cancel_js,
            phx_target: @myself
          })}
        <% end %>

        <%= if not @show_step_nav or last_step?(assigns) do %>
          <button
            type="submit"
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            {@submit_label}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_field_by_type(assigns) do
    ui = assigns.ui
    field = assigns.field_config
    form_field = assigns.form_field
    label = assigns.label
    errors = assigns.errors

    wrapper_assigns = %{
      label: label,
      field: form_field,
      errors: errors,
      required: Map.get(field, :required, false),
      inner_block: render_input(ui, field, form_field, assigns)
    }

    ui.field_wrapper(wrapper_assigns)
  end

  defp render_input(ui, field, form_field, assigns) do
    type = Map.get(field, :type, :text)

    base = %{
      field: form_field,
      name: field.name,
      id: "form-#{field.name}",
      value: Phoenix.HTML.Form.input_value(assigns.state.form, field.name),
      placeholder: get_in_map(field, [:ui, :placeholder]),
      disabled: Map.get(field, :disabled, false)
    }

    case type do
      t when t in [:text, :email, :password, :url, :tel, :hidden] ->
        ui.text_input(Map.put(base, :type, to_string(t)))

      :number ->
        ui.number_input(base)

      :textarea ->
        ui.textarea(base)

      :select ->
        options = Map.get(field, :options, [])
        ui.select(Map.put(base, :options, options))

      :multi_select ->
        options = Map.get(field, :options, [])
        ui.multi_select(Map.put(base, :options, options))

      :checkbox ->
        ui.checkbox(base)

      :toggle ->
        ui.toggle_input(base)

      :date ->
        ui.date_input(base)

      :datetime ->
        ui.datetime_input(base)

      :range ->
        min = get_in_map(field, [:ui, :min]) || 0
        max = get_in_map(field, [:ui, :max]) || 100
        ui.range_input(Map.merge(base, %{min: min, max: max}))

      :json ->
        ui.json_editor(base)

      :search_select ->
        options = Map.get(assigns.state.relation_options, field.name, %{})
        ui.search_select(Map.merge(base, %{options: Map.get(options, :options, [])}))

      :file ->
        render_upload_field(ui, field, assigns)

      _ ->
        ui.text_input(Map.put(base, :type, "text"))
    end
  end

  defp render_upload_field(ui, field, assigns) do
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
      ui.text_input(%{
        name: field.name,
        id: "form-#{field.name}",
        value: "",
        type: "file"
      })
    end
  end

  defp render_upload_by_style(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= case @style do %>
        <% :dropzone -> %>
          <%= if @upload do %>
            {@ui.upload_dropzone(%{
              upload_ref: @upload.ref,
              accept: @upload_config[:accept],
              max_entries: @upload_config[:max_entries] || 1,
              inner_block: render_live_file_input(assigns, "sr-only")
            })}
          <% end %>
        <% :file_input -> %>
          <%= if @upload do %>
            {@ui.upload_file_input(%{
              accept: @upload_config[:accept],
              max_entries: @upload_config[:max_entries] || 1,
              inner_block: render_live_file_input(assigns, nil)
            })}
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

      <%= if @existing_files != [] do %>
        {render_existing_files(assigns)}
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
        <div class="flex items-center gap-2">
          <div class="flex-1">
            <%= if entry.progress < 100 do %>
              {@ui.upload_progress(%{entry: entry})}
            <% else %>
              {@ui.upload_preview(%{entry: entry})}
            <% end %>
          </div>
          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-key={@ns_name}
            phx-value-ref={entry.ref}
            phx-target={@myself}
            class="text-gray-400 hover:text-red-500 transition-colors"
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
      <p class="text-xs font-medium text-gray-500 uppercase tracking-wide">Existing files</p>
      <%= for file <- @existing_files do %>
        {@ui.upload_existing_file(%{
          file: file,
          filename: file[:filename] || file[:name] || "File",
          file_id: file[:id] || file[:filename] || file[:name],
          upload_name: @upload_config.name,
          phx_target: @myself
        })}
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
    case assigns.static[:hooks] do
      %{js: %{^hook_name => func}} when is_function(func, 0) -> func.()
      %{js: %{^hook_name => func}} when is_function(func, 1) -> func.(assigns[:record_id])
      _ -> %JS{}
    end
  end
end

defmodule MishkaGervaz.Form.Templates.Standard do
  @moduledoc """
  Default form template for MishkaGervaz.

  Renders forms using the configured UI adapter for component styling.
  Supports standard, wizard, and tabs layout modes.
  """

  @behaviour MishkaGervaz.Form.Behaviours.Template
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  import MishkaGervaz.Helpers, only: [get_ui_label: 1, dynamic_component: 1, resolve_label: 1]
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

          {render_uploads_section(assigns)}
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

    assigns =
      assigns
      |> assign(:group_label, Map.get(group, :resolved_label, ""))
      |> assign(:group_fields, Map.get(group, :resolved_fields, []))
      |> assign(:ui, assigns.static.ui_adapter)
      |> assign(:collapsible, Map.get(group, :collapsible, false))

    ~H"""
    <div>
      <.dynamic_component
        module={@ui}
        function={:field_group}
        label={@group_label}
        collapsible={@collapsible}
        open={true}
      >
        {render_group_fields(assigns, @group_fields)}
      </.dynamic_component>
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
      <.dynamic_component module={@ui} function={:step_indicator} steps={@step_data} current={@current_step} />
    </div>
    """
  end

  defp render_groups(assigns) do
    groups = assigns.static.groups

    if groups == [] do
      # No explicit groups — render all fields in a flat layout
      render_group_fields(assigns, assigns.static.fields)
    else
      assigns = assign(assigns, :all_groups, groups)

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
        do: resolve_label(Map.get(submit, :create_label, "Create")),
        else: resolve_label(Map.get(submit, :update_label, "Update"))

    cancel_js =
      assigns
      |> resolve_js_hook(:on_cancel)
      |> JS.push("cancel", target: assigns.myself)

    assigns =
      assigns
      |> assign(:submit_label, submit_label)
      |> assign(:cancel_label, resolve_label(Map.get(submit, :cancel_label, "Cancel")))
      |> assign(:show_cancel, Map.get(submit, :show_cancel, true))
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
            phx_click={@cancel_js}
            phx_target={@myself}
          />
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

  defp render_uploads_section(assigns) do
    uploads = assigns.static.uploads

    if is_list(uploads) and uploads != [] do
      ui = assigns.static.ui_adapter
      upload_items = build_upload_items(uploads, assigns)
      assigns = assigns |> assign(:upload_items, upload_items) |> assign(:ui, ui)

      ~H"""
      <div class="space-y-4 mt-4">
        <%= for item <- @upload_items do %>
          <% ua = build_upload_assigns(assigns, item) %>
          {render_upload_by_style(ua)}
        <% end %>
      </div>
      """
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

  defp render_input(ui, field, form_field, assigns) do
    type = Map.get(field, :type, :text)

    base =
      assigns
      |> assign(:field, form_field)
      |> assign(:name, field.name)
      |> assign(:id, "form-#{field.name}")
      |> assign(:value, Phoenix.HTML.Form.input_value(assigns.state.form, field.name))
      |> assign(:placeholder, get_in_map(field, [:ui, :placeholder]))
      |> assign(:disabled, Map.get(field, :disabled, false))
      |> assign(:module, ui)

    case type do
      t when t in [:text, :email, :password, :url, :tel, :hidden] ->
        base |> assign(:function, :text_input) |> assign(:type, to_string(t)) |> dynamic_component()

      :number ->
        base |> assign(:function, :number_input) |> dynamic_component()

      :textarea ->
        base |> assign(:function, :textarea) |> dynamic_component()

      :select ->
        options = Map.get(field, :options, [])
        base |> assign(:function, :select) |> assign(:options, options) |> dynamic_component()

      :multi_select ->
        options = Map.get(field, :options, [])

        base
        |> assign(:function, :multi_select)
        |> assign(:options, options)
        |> dynamic_component()

      :checkbox ->
        base |> assign(:function, :checkbox) |> dynamic_component()

      :toggle ->
        base |> assign(:function, :toggle_input) |> dynamic_component()

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
        base |> assign(:function, :json_editor) |> dynamic_component()

      :search_select ->
        options = Map.get(assigns.state.relation_options, field.name, %{})

        base
        |> assign(:function, :search_select)
        |> assign(:options, Map.get(options, :options, []))
        |> dynamic_component()

      :file ->
        render_upload_field(ui, field, assigns)

      _ ->
        base |> assign(:function, :text_input) |> assign(:type, "text") |> dynamic_component()
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
      assigns
      |> assign(:module, ui)
      |> assign(:function, :text_input)
      |> assign(:name, field.name)
      |> assign(:id, "form-#{field.name}")
      |> assign(:value, "")
      |> assign(:type, "file")
      |> dynamic_component()
    end
  end

  defp render_upload_by_style(assigns) do
    ~H"""
    <div class="space-y-3">
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
        <%!-- entry is used directly in dynamic_component calls below --%>
        <div class="flex items-center gap-2">
          <div class="flex-1">
            <%= if entry.progress < 100 do %>
              <.dynamic_component module={@ui} function={:upload_progress} entry={entry} />
            <% else %>
              <.dynamic_component module={@ui} function={:upload_preview} entry={entry} />
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
      %{js: %{^hook_name => func}} when is_function(func, 0) -> func.()
      %{js: %{^hook_name => func}} when is_function(func, 1) -> func.(Map.get(assigns, :record_id))
      _ -> %JS{}
    end
  end
end

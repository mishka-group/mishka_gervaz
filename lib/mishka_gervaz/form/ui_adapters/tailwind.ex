defmodule MishkaGervaz.Form.UIAdapters.Tailwind do
  @moduledoc """
  Default Tailwind CSS UI adapter for forms.

  Provides plain Tailwind-styled components for form rendering.
  This is the default adapter used when no other is specified.

  Implements both shared components (matching the table adapter pattern)
  and form-specific components like field wrappers, step indicators,
  upload zones, and nested field containers.
  """

  @behaviour MishkaGervaz.Form.Behaviours.UIAdapter
  use Phoenix.Component

  import MishkaGervaz.Helpers,
    only: [normalize_options: 1, normalize_selected_values: 1, resolve_label: 1]

  @impl true
  def text_input(assigns) do
    placeholder =
      assigns[:placeholder] ||
        if assigns[:placeholder_label], do: "Search #{assigns[:placeholder_label]}..."

    assigns =
      assigns
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:phx_debounce, fn -> 300 end)
      |> assign_new(:icon, fn -> nil end)
      |> assign(:placeholder, placeholder)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
      />
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class={[@class, @icon && "pl-9"]}
        phx-debounce={@phx_debounce}
      />
    </div>
    """
  end

  @impl true
  def select(assigns) do
    normalized = normalize_options(assigns[:options] || [])

    assigns =
      assigns
      |> assign(:options, normalized)
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:prompt, fn -> "Select..." end)
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none"
      />
      <select name={@name} class={[@class, @icon && "pl-9"]}>
        <option :if={@prompt} value="">{@prompt}</option>
        <%= for {label, value} <- @options do %>
          <option value={value} selected={to_string(@value) == to_string(value)}>
            {label}
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  @impl true
  def multi_select(assigns) do
    options = normalize_options(assigns[:options] || [])
    selected = normalize_selected_values(assigns[:selected])
    selected_options = normalize_options(assigns[:selected_options] || [])
    selected_set = MapSet.new(selected, &to_string/1)
    display_options = build_display_options(options, selected_options, selected_set)

    assigns =
      assigns
      |> assign(:options, options)
      |> assign(:display_options, display_options)
      |> assign(:selected, selected)
      |> assign(:selected_set, selected_set)
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:placeholder, fn -> "Search..." end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:loading?, fn -> false end)
      |> assign_new(:dropdown_open?, fn -> false end)
      |> assign_new(:min_chars, fn -> 2 end)
      |> assign_new(:debounce, fn -> 300 end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:filter_name, fn -> assigns[:name] end)
      |> assign_new(:myself, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"multi-select-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <div class="relative">
        <.render_icon
          :if={@icon}
          name={@icon}
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none z-10"
        />
        <input
          type="text"
          name={"_search_#{@filter_name}"}
          placeholder={@placeholder}
          class={[@class, @icon && "pl-9", "w-full"]}
          phx-debounce={@debounce}
          phx-keyup="relation_search"
          phx-focus="relation_focus"
          phx-target={@myself}
          phx-value-filter={@filter_name}
          phx-value-min-chars={@min_chars}
          autocomplete="off"
        />
        <span
          :if={@loading?}
          class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 border-2 border-gray-300 border-t-blue-500 rounded-full animate-spin"
        />
      </div>

      <input :for={val <- @selected} type="hidden" name={"#{@name}[]"} value={val} />

      <div
        :if={@dropdown_open? and @display_options != []}
        class="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
      >
        <button
          :for={{label, value} <- @display_options}
          type="button"
          class={[
            "w-full px-3 py-2 text-left text-sm hover:bg-gray-100 flex items-center gap-2",
            selected?(value, @selected_set) && "bg-blue-50"
          ]}
          phx-click="relation_toggle"
          phx-target={@myself}
          phx-value-filter={@filter_name}
          phx-value-id={value}
          phx-value-label={label}
        >
          <span class={checkbox_class(value, @selected_set)}>
            <.render_icon :if={selected?(value, @selected_set)} name="hero-check" class="w-3 h-3" />
          </span>
          {label}
        </button>

        <button
          :if={@has_more?}
          type="button"
          phx-click="relation_load_more"
          phx-target={@myself}
          phx-value-filter={@filter_name}
          class="w-full px-3 py-2 text-left text-sm text-blue-600 hover:bg-gray-100 border-t border-gray-100"
        >
          Load more...
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def search_select(assigns) do
    options = normalize_options(assigns[:options] || [])
    current_value = assigns[:value] || ""
    selected_options = normalize_options(assigns[:selected_options] || [])

    display_options =
      if current_value != "" do
        all_opts = options ++ selected_options
        Enum.uniq_by(all_opts, fn {_, v} -> to_string(v) end)
      else
        options
      end

    assigns =
      assigns
      |> assign(:options, options)
      |> assign(:display_options, display_options)
      |> assign(:current_value, current_value)
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:placeholder, fn -> "Search..." end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:loading?, fn -> false end)
      |> assign_new(:dropdown_open?, fn -> false end)
      |> assign_new(:min_chars, fn -> 2 end)
      |> assign_new(:debounce, fn -> 300 end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:filter_name, fn -> assigns[:name] end)
      |> assign_new(:myself, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"search-select-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <div class="relative">
        <.render_icon
          :if={@icon}
          name={@icon}
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none z-10"
        />
        <input
          type="text"
          name={"_search_#{@filter_name}"}
          placeholder={@placeholder}
          class={[@class, @icon && "pl-9", "w-full"]}
          phx-debounce={@debounce}
          phx-keyup="relation_search"
          phx-focus="relation_focus"
          phx-target={@myself}
          phx-value-filter={@filter_name}
          phx-value-min-chars={@min_chars}
          autocomplete="off"
        />
        <span
          :if={@loading?}
          class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 border-2 border-gray-300 border-t-blue-500 rounded-full animate-spin"
        />
      </div>

      <input type="hidden" name={@name} value={@current_value} />

      <div
        :if={@dropdown_open? and @display_options != []}
        class="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
      >
        <button
          :for={{opt_label, opt_value} <- @display_options}
          type="button"
          class={[
            "w-full px-3 py-2 text-left text-sm hover:bg-gray-100",
            to_string(@current_value) == to_string(opt_value) && "bg-blue-50 text-blue-700"
          ]}
          phx-click="relation_select"
          phx-target={@myself}
          phx-value-filter={@filter_name}
          phx-value-id={opt_value}
          phx-value-label={opt_label}
        >
          {opt_label}
        </button>

        <button
          :if={@has_more?}
          type="button"
          phx-click="relation_load_more"
          phx-target={@myself}
          phx-value-filter={@filter_name}
          class="w-full px-3 py-2 text-left text-sm text-blue-600 hover:bg-gray-100 border-t border-gray-100"
        >
          Load more...
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def checkbox(assigns) do
    label = resolve_label(assigns[:label])

    assigns =
      assigns
      |> assign_new(:class, fn -> "rounded border-gray-300 text-blue-600 focus:ring-blue-500" end)
      |> assign(:label, label)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:checked, fn -> false end)

    ~H"""
    <label class="inline-flex items-center gap-2">
      <.render_icon :if={@icon} name={@icon} class="w-4 h-4 text-gray-400" />
      <input
        type="checkbox"
        name={@name}
        value={@value}
        checked={@checked}
        class={@class}
      />
      <span :if={@label} class="text-sm text-gray-700">{@label}</span>
    </label>
    """
  end

  @impl true
  def date_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:min, fn -> nil end)
      |> assign_new(:max, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
      />
      <input
        type="date"
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        class={[@class, @icon && "pl-9"]}
      />
    </div>
    """
  end

  @impl true
  def datetime_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
      />
      <input
        type="datetime-local"
        name={@name}
        value={@value}
        class={[@class, @icon && "pl-9"]}
      />
    </div>
    """
  end

  @impl true
  def number_input(assigns) do
    placeholder = assigns[:placeholder] || assigns[:placeholder_label]

    assigns =
      assigns
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:step, fn -> "any" end)
      |> assign(:placeholder, placeholder)
      |> assign_new(:min, fn -> nil end)
      |> assign_new(:max, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
      />
      <input
        type="number"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        min={@min}
        max={@max}
        step={@step}
        class={[@class, @icon && "pl-9"]}
      />
    </div>
    """
  end

  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :type, :string, default: "button"
  attr :icon, :string, default: nil
  attr :variant, :atom, default: :default

  attr :rest, :global,
    include: ~w(phx-click phx-target phx-value-id phx-value-event phx-value-values data-confirm disabled)

  @impl true
  def button(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> button_class(assigns[:variant]) end)
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <button type={@type} class={@class} {@rest}>
      <.render_icon :if={@icon} name={@icon} class="w-4 h-4 inline-block mr-1" />
      {@label}
    </button>
    """
  end

  @impl true
  def icon(assigns) do
    variant = assigns[:variant] || :default

    assigns =
      assigns
      |> assign_new(:name, fn -> icon_name(variant) end)
      |> assign_new(:class, fn -> icon_class(variant) end)

    ~H"""
    <.render_icon name={@name} class={@class} />
    """
  end

  @impl true
  def badge(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn ->
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
      end)

    ~H"""
    <span class={@class}>{@label}</span>
    """
  end

  @impl true
  def spinner(assigns) do
    assigns = assign_new(assigns, :class, fn -> "w-6 h-6" end)

    ~H"""
    <div class={["animate-spin rounded-full border-b-2 border-gray-900", @class]}></div>
    """
  end

  @impl true
  def empty_state(assigns) do
    assigns =
      assigns
      |> assign_new(:message, fn -> "No data available" end)
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <div class="py-12 text-center">
      <div :if={@icon} class="mb-4">
        <.render_icon name={@icon} class="w-12 h-12 mx-auto text-gray-400" />
      </div>
      <p class="text-gray-500 text-lg">{@message}</p>
    </div>
    """
  end

  @impl true
  def error_state(assigns) do
    assigns =
      assigns
      |> assign_new(:message, fn -> "Something went wrong" end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:retry_label, fn -> nil end)
      |> assign_new(:target, fn -> nil end)

    ~H"""
    <div class="p-8 text-center text-red-500">
      <.render_icon :if={@icon} name={@icon} class="w-12 h-12 mx-auto mb-4" />
      <div class="text-lg font-semibold">{@message}</div>
      <div :if={@retry_label} class="mt-4">
        <button
          type="button"
          phx-click="retry"
          phx-target={@target}
          class="px-4 py-2 bg-red-100 text-red-700 rounded-md hover:bg-red-200 transition-colors"
        >
          {@retry_label}
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def form_container(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "space-y-6" end)
      |> assign_new(:phx_change, fn -> nil end)
      |> assign_new(:phx_submit, fn -> nil end)
      |> assign_new(:phx_target, fn -> nil end)

    ~H"""
    <form
      id={@id}
      phx-change={@phx_change}
      phx-submit={@phx_submit}
      phx-target={@phx_target}
      class={@class}
      novalidate
    >
      {render_slot(@inner_block)}
    </form>
    """
  end

  @impl true
  def field_wrapper(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:field_name, fn -> nil end)
      |> assign_new(:required, fn -> false end)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:class, fn -> "space-y-1" end)

    has_errors = assigns.errors != []
    assigns = assign(assigns, :has_errors, has_errors)

    ~H"""
    <div class={@class}>
      <label :if={@label} class="block text-sm font-medium text-gray-700" for={@field_name}>
        {@label}
        <span :if={@required} class="text-red-500 ml-0.5">*</span>
      </label>
      <div class={[@has_errors && "ring-1 ring-red-500 rounded-md"]}>
        {render_slot(@inner_block)}
      </div>
      <.field_error :if={@has_errors} errors={@errors} />
    </div>
    """
  end

  @impl true
  def field_group(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:collapsible, fn -> false end)
      |> assign_new(:collapsed, fn -> false end)
      |> assign_new(:class, fn -> "border border-gray-200 rounded-lg p-4" end)

    ~H"""
    <fieldset class={@class}>
      <%= if @collapsible do %>
        <legend class="px-2">
          <details open={!@collapsed}>
            <summary class="cursor-pointer text-sm font-semibold text-gray-900 select-none">
              {@label}
            </summary>
            <p :if={@description} class="mt-1 text-sm text-gray-500">{@description}</p>
            <div class="mt-4 space-y-4">
              {render_slot(@inner_block)}
            </div>
          </details>
        </legend>
      <% else %>
        <legend :if={@label} class="px-2 text-sm font-semibold text-gray-900">
          {@label}
        </legend>
        <p :if={@description} class="mt-1 text-sm text-gray-500">{@description}</p>
        <div class="mt-4 space-y-4">
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </fieldset>
    """
  end

  @impl true
  def step_indicator(assigns) do
    assigns =
      assigns
      |> assign_new(:steps, fn -> [] end)
      |> assign_new(:current_step, fn -> nil end)
      |> assign_new(:class, fn -> "flex items-center justify-center" end)

    ~H"""
    <nav class={@class} aria-label="Progress">
      <ol class="flex items-center space-x-2">
        <%= for {step, index} <- Enum.with_index(@steps) do %>
          <li class="flex items-center">
            <%!-- Connector line before step (except first) --%>
            <div
              :if={index > 0}
              class={[
                "w-8 h-0.5 mx-1",
                step_connector_class(step.status)
              ]}
            />
            <%!-- Step circle --%>
            <div class="flex flex-col items-center">
              <div class={[
                "flex items-center justify-center w-8 h-8 rounded-full border-2 text-xs font-medium",
                step_circle_class(step.status, step.name == @current_step)
              ]}>
                <%= cond do %>
                  <% step.status == :complete -> %>
                    <.render_icon name="hero-check" class="w-4 h-4" />
                  <% step[:icon] -> %>
                    <.render_icon name={step.icon} class="w-4 h-4" />
                  <% true -> %>
                    {index + 1}
                <% end %>
              </div>
              <span class={[
                "mt-1 text-xs",
                step_label_class(step.status, step.name == @current_step)
              ]}>
                {step.label}
              </span>
            </div>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  @impl true
  def step_navigation(assigns) do
    assigns =
      assigns
      |> assign_new(:can_go_back, fn -> false end)
      |> assign_new(:can_advance, fn -> true end)
      |> assign_new(:is_last_step, fn -> false end)
      |> assign_new(:prev_label, fn -> "Back" end)
      |> assign_new(:next_label, fn -> "Next" end)
      |> assign_new(:submit_label, fn -> "Submit" end)
      |> assign_new(:phx_target, fn -> nil end)
      |> assign_new(:class, fn -> "flex items-center justify-between pt-6 border-t border-gray-200" end)

    ~H"""
    <div class={@class}>
      <button
        :if={@can_go_back}
        type="button"
        phx-click="prev_step"
        phx-target={@phx_target}
        class="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 transition-colors"
      >
        <.render_icon name="hero-arrow-left" class="w-4 h-4" />
        {@prev_label}
      </button>
      <div :if={!@can_go_back} />

      <%= if @is_last_step do %>
        <button
          type="submit"
          class="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md shadow-sm hover:bg-blue-700 focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
        >
          {@submit_label}
          <.render_icon name="hero-check" class="w-4 h-4" />
        </button>
      <% else %>
        <button
          type="button"
          phx-click="next_step"
          phx-target={@phx_target}
          disabled={!@can_advance}
          class={[
            "inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white rounded-md shadow-sm transition-colors",
            @can_advance && "bg-blue-600 hover:bg-blue-700 focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
            !@can_advance && "bg-gray-400 cursor-not-allowed"
          ]}
        >
          {@next_label}
          <.render_icon name="hero-arrow-right" class="w-4 h-4" />
        </button>
      <% end %>
    </div>
    """
  end

  @impl true
  def upload_dropzone(assigns) do
    assigns =
      assigns
      |> assign_new(:accept, fn -> nil end)
      |> assign_new(:max_entries, fn -> 1 end)
      |> assign_new(:class, fn ->
        "flex flex-col items-center justify-center w-full px-6 py-10 border-2 border-dashed border-gray-300 rounded-lg hover:border-blue-400 transition-colors cursor-pointer bg-gray-50"
      end)

    ~H"""
    <div class={@class} phx-drop-target={@upload_ref}>
      <.render_icon name="hero-cloud-arrow-up" class="w-10 h-10 text-gray-400 mb-3" />
      <p class="text-sm text-gray-600">
        <span class="font-semibold text-blue-600">Click to upload</span>
        or drag and drop
      </p>
      <p :if={@accept} class="mt-1 text-xs text-gray-500">
        {format_accept(@accept)}
      </p>
      <p :if={@max_entries > 1} class="mt-1 text-xs text-gray-500">
        Up to {@max_entries} files
      </p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @impl true
  def upload_preview(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "flex items-center gap-3 p-3 bg-gray-50 rounded-md" end)

    ~H"""
    <div class={@class}>
      <.render_icon name="hero-document" class="w-8 h-8 text-gray-400 shrink-0" />
      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium text-gray-900 truncate">{@entry.client_name}</p>
        <p class="text-xs text-gray-500">{format_filesize(@entry.client_size)}</p>
      </div>
    </div>
    """
  end

  @impl true
  def upload_progress(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "w-full" end)

    ~H"""
    <div class={@class}>
      <div class="flex items-center justify-between mb-1">
        <span class="text-xs font-medium text-gray-700 truncate">{@entry.client_name}</span>
        <span class="text-xs text-gray-500">{@entry.progress}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-1.5">
        <div
          class="bg-blue-600 h-1.5 rounded-full transition-all duration-300 ease-out"
          style={"width: #{@entry.progress}%"}
        />
      </div>
    </div>
    """
  end

  @impl true
  def toggle_input(assigns) do
    assigns =
      assigns
      |> assign_new(:checked, fn -> false end)
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:class, fn -> "relative inline-flex items-center" end)

    ~H"""
    <label class={[@class, "cursor-pointer gap-3"]}>
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        name={@name}
        value={@value}
        checked={@checked}
        class="sr-only peer"
      />
      <div class={[
        "w-11 h-6 rounded-full transition-colors duration-200 ease-in-out",
        "bg-gray-200 peer-checked:bg-blue-600",
        "after:content-[''] after:absolute after:top-0.5 after:start-[2px]",
        "after:bg-white after:border after:border-gray-300 after:rounded-full",
        "after:h-5 after:w-5 after:transition-all after:duration-200",
        "peer-checked:after:translate-x-full peer-checked:after:border-white",
        "peer-focus:ring-2 peer-focus:ring-blue-300"
      ]} />
      <span :if={@label} class="text-sm font-medium text-gray-700">{@label}</span>
    </label>
    """
  end

  @impl true
  def range_input(assigns) do
    assigns =
      assigns
      |> assign_new(:min, fn -> 0 end)
      |> assign_new(:max, fn -> 100 end)
      |> assign_new(:step, fn -> 1 end)
      |> assign_new(:class, fn -> "w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-blue-600" end)
      |> assign_new(:show_value, fn -> false end)

    ~H"""
    <div class="flex items-center gap-3">
      <input
        type="range"
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        step={@step}
        class={@class}
      />
      <span :if={@show_value} class="text-sm font-medium text-gray-700 tabular-nums min-w-[3ch] text-right">
        {@value}
      </span>
    </div>
    """
  end

  @impl true
  def textarea(assigns) do
    assigns =
      assigns
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm shadow-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:rows, fn -> 4 end)
      |> assign_new(:phx_debounce, fn -> 300 end)

    ~H"""
    <textarea
      name={@name}
      placeholder={@placeholder}
      rows={@rows}
      class={@class}
      phx-debounce={@phx_debounce}
    >{@value}</textarea>
    """
  end

  @impl true
  def json_editor(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn ->
        "w-full rounded-md border-gray-300 px-3 py-2 text-sm font-mono shadow-sm focus:ring-blue-500 focus:border-blue-500 bg-gray-50"
      end)
      |> assign_new(:rows, fn -> 8 end)

    ~H"""
    <textarea
      name={@name}
      rows={@rows}
      class={@class}
      spellcheck="false"
    >{@value}</textarea>
    """
  end

  @impl true
  def nested_fields(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:class, fn -> "space-y-4" end)
      |> assign_new(:add_label, fn -> "Add item" end)
      |> assign_new(:phx_target, fn -> nil end)
      |> assign_new(:field_path, fn -> nil end)

    ~H"""
    <div class={@class}>
      <div :if={@label} class="flex items-center justify-between">
        <h4 class="text-sm font-semibold text-gray-900">{@label}</h4>
      </div>
      <div class="space-y-3">
        {render_slot(@inner_block)}
      </div>
      <button
        type="button"
        phx-click="add_nested"
        phx-target={@phx_target}
        phx-value-path={@field_path}
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors"
      >
        <.render_icon name="hero-plus" class="w-4 h-4" />
        {@add_label}
      </button>
    </div>
    """
  end

  @impl true
  def array_fields(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:class, fn -> "space-y-3" end)
      |> assign_new(:add_label, fn -> "Add item" end)
      |> assign_new(:phx_target, fn -> nil end)
      |> assign_new(:field_path, fn -> nil end)

    ~H"""
    <div class={@class}>
      <div :if={@label} class="flex items-center justify-between">
        <h4 class="text-sm font-semibold text-gray-900">{@label}</h4>
      </div>
      <div class="space-y-2">
        {render_slot(@inner_block)}
      </div>
      <button
        type="button"
        phx-click="add_array_item"
        phx-target={@phx_target}
        phx-value-path={@field_path}
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors"
      >
        <.render_icon name="hero-plus" class="w-4 h-4" />
        {@add_label}
      </button>
    </div>
    """
  end

  @impl true
  def field_error(assigns) do
    assigns =
      assigns
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:class, fn -> "mt-1" end)

    ~H"""
    <div :if={@errors != []} class={@class}>
      <p :for={error <- @errors} class="text-sm text-red-600 flex items-center gap-1">
        <.render_icon name="hero-exclamation-circle" class="w-4 h-4 shrink-0" />
        {error}
      </p>
    </div>
    """
  end

  defp button_class(:primary),
    do: "px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md shadow-sm hover:bg-blue-700 focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"

  defp button_class(:danger),
    do: "px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md shadow-sm hover:bg-red-700 focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"

  defp button_class(:secondary),
    do: "px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 transition-colors"

  defp button_class(_),
    do: "px-3 py-2 text-sm rounded-md hover:bg-gray-100 transition-colors"

  defp icon_name(:boolean_true), do: "hero-check"
  defp icon_name(:boolean_false), do: "hero-x-mark"
  defp icon_name(_), do: nil

  defp icon_class(:boolean_true), do: "w-5 h-5 text-green-600"
  defp icon_class(:boolean_false), do: "w-5 h-5 text-red-600"
  defp icon_class(_), do: "w-5 h-5"

  defp selected?(value, selected_set), do: to_string(value) in selected_set

  defp checkbox_class(value, selected_set) do
    base = "w-4 h-4 border rounded flex items-center justify-center"

    if selected?(value, selected_set) do
      "#{base} bg-blue-500 border-blue-500 text-white"
    else
      "#{base} border-gray-300"
    end
  end

  defp build_display_options(options, selected_options, selected_set) do
    all_options = options ++ selected_options

    {_, deduped} =
      Enum.reduce(all_options, {MapSet.new(), []}, fn {label, value}, {seen, acc} ->
        str_value = to_string(value)

        if str_value in seen do
          {seen, acc}
        else
          {MapSet.put(seen, str_value), [{label, value} | acc]}
        end
      end)

    deduped = Enum.reverse(deduped)
    {selected, unselected} = Enum.split_with(deduped, fn {_, v} -> selected?(v, selected_set) end)
    selected ++ unselected
  end

  defp step_circle_class(:complete, _current),
    do: "bg-blue-600 border-blue-600 text-white"

  defp step_circle_class(_status, true),
    do: "border-blue-600 text-blue-600 bg-white"

  defp step_circle_class(:error, _current),
    do: "border-red-500 text-red-500 bg-white"

  defp step_circle_class(_status, false),
    do: "border-gray-300 text-gray-400 bg-white"

  defp step_connector_class(:complete), do: "bg-blue-600"
  defp step_connector_class(_), do: "bg-gray-300"

  defp step_label_class(:complete, _current), do: "text-blue-600 font-medium"
  defp step_label_class(_status, true), do: "text-blue-600 font-medium"
  defp step_label_class(:error, _current), do: "text-red-500"
  defp step_label_class(_, _), do: "text-gray-500"

  defp format_accept(nil), do: ""
  defp format_accept(accept) when is_binary(accept), do: accept
  defp format_accept(accept) when is_list(accept), do: Enum.join(accept, ", ")

  defp format_filesize(nil), do: "-"

  defp format_filesize(size) when is_integer(size) do
    cond do
      size < 1024 -> "#{size} B"
      size < 1024 * 1024 -> "#{Float.round(size / 1024, 1)} KB"
      size < 1024 * 1024 * 1024 -> "#{Float.round(size / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  defp format_filesize(_), do: "-"

  defp render_icon(assigns) do
    name = assigns[:name] || ""
    class = assigns[:class] || "w-5 h-5"

    if String.starts_with?(name, "hero-") do
      icon_name = String.replace_prefix(name, "hero-", "")

      assigns = %{name: icon_name, class: class}

      ~H"""
      <span class={["hero-#{@name}", @class]}></span>
      """
    else
      assigns = %{class: class}

      ~H"""
      <span class={@class}></span>
      """
    end
  end
end

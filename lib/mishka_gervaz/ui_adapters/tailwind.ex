defmodule MishkaGervaz.UIAdapters.Tailwind do
  @moduledoc """
  Default Tailwind CSS UI adapter.

  Provides plain Tailwind-styled components for tables and forms.
  This is the default adapter used when no other is specified.
  """

  @behaviour MishkaGervaz.Behaviours.UIAdapter
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias MishkaGervaz.Table.Templates.Shared

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
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:phx_debounce, fn -> 300 end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
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
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && "bg-gray-100 cursor-not-allowed"]}
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
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:prompt, fn -> "All" end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none"
      />
      <select
        name={@name}
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && "bg-gray-100 cursor-not-allowed"]}
      >
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

  @doc """
  Single-select dropdown with search support for relation filters.

  EXACT COPY of multi_select adapted for single selection.
  """
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
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
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
      |> assign_new(:search_term, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"search-select-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <%!-- Search input --%>
      <div class="relative">
        <.render_icon
          :if={@icon}
          name={@icon}
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none z-10"
        />
        <input
          type="text"
          name={"_search_#{@filter_name}"}
          value={@search_term || ""}
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

      <%!-- Hidden input for form submission --%>
      <input type="hidden" name={@name} value={@current_value} />

      <%!-- Dropdown options (only show when open) --%>
      <div
        :if={@dropdown_open?}
        class="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
      >
        <div :if={@display_options == []} class="px-3 py-2 text-sm text-gray-400">
          No records found
        </div>
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

  @doc """
  Single-select dropdown with paginated load-more (no search input).

  Shows a clickable trigger that opens a dropdown with options and a
  "Load more" button for pagination.
  """
  @impl true
  def load_more_select(assigns) do
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

    selected_label =
      case Enum.find(selected_options, fn {_, v} -> to_string(v) == to_string(current_value) end) do
        {label, _} ->
          label

        nil ->
          case Enum.find(options, fn {_, v} -> to_string(v) == to_string(current_value) end) do
            {label, _} -> label
            nil -> nil
          end
      end

    assigns =
      assigns
      |> assign(:options, options)
      |> assign(:display_options, display_options)
      |> assign(:current_value, current_value)
      |> assign(:selected_label, selected_label)
      |> assign_new(:class, fn ->
        "rounded border border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:placeholder, fn -> "Select..." end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:loading?, fn -> false end)
      |> assign_new(:dropdown_open?, fn -> false end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:filter_name, fn -> assigns[:name] end)
      |> assign_new(:myself, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"load-more-select-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <%!-- Clickable trigger --%>
      <button
        type="button"
        class={[@class, "w-full text-left flex items-center justify-between cursor-pointer bg-white"]}
        phx-click="relation_focus"
        phx-target={@myself}
        phx-value-filter={@filter_name}
      >
        <span class={[!@selected_label && "text-gray-400"]}>
          {@selected_label || @placeholder}
        </span>
        <span class="ml-2 text-gray-400">
          <.render_icon
            name="hero-chevron-down"
            class={["w-4 h-4 transition-transform", @dropdown_open? && "rotate-180"]}
          />
        </span>
      </button>

      <%!-- Hidden input for form submission --%>
      <input type="hidden" name={@name} value={@current_value} />

      <%!-- Dropdown options (only show when open) --%>
      <div
        :if={@dropdown_open?}
        class="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
      >
        <div :if={@display_options == []} class="px-3 py-2 text-sm text-gray-400">
          No records found
        </div>
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

      <%!-- Loading spinner --%>
      <span
        :if={@loading?}
        class="absolute right-8 top-1/2 -translate-y-1/2 w-4 h-4 border-2 border-gray-300 border-t-blue-500 rounded-full animate-spin"
      />
    </div>
    """
  end

  @doc """
  Multi-select dropdown with search support for relation filters.

  Shows a searchable dropdown where users can select multiple items.
  Selected items appear with checkmarks in the dropdown.
  """
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
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
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
      |> assign_new(:search_term, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"multi-select-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <%!-- Search input --%>
      <div class="relative">
        <.render_icon
          :if={@icon}
          name={@icon}
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none z-10"
        />
        <input
          type="text"
          name={"_search_#{@filter_name}"}
          value={@search_term || ""}
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

      <%!-- Hidden inputs for form submission --%>
      <input :for={val <- @selected} type="hidden" name={"#{@name}[]"} value={val} />

      <%!-- Dropdown options (only show when open) --%>
      <div
        :if={@dropdown_open?}
        class="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
      >
        <div :if={@display_options == []} class="px-3 py-2 text-sm text-gray-400">
          No records found
        </div>
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
  def checkbox(assigns) do
    label = resolve_label(assigns[:label])

    assigns =
      assigns
      |> assign_new(:id, fn -> nil end)
      |> assign_new(:class, fn -> "rounded border-gray-300 text-blue-600 focus:ring-blue-500" end)
      |> assign(:label, label)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:checked, fn -> false end)
      |> assign_new(:hidden_input, fn -> false end)
      |> assign(:phx_click, assigns[:"phx-click"])
      |> assign(:phx_target, assigns[:"phx-target"])
      |> assign(:phx_value_id, assigns[:"phx-value-id"])
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <label class="flex items-center gap-2">
      <.render_icon :if={@icon} name={@icon} class="w-4 h-4 text-gray-400" />
      <input :if={@hidden_input} type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value={@value}
        checked={@checked}
        disabled={@disabled}
        class={[@class, @disabled && "cursor-not-allowed"]}
        phx-click={@phx_click}
        phx-target={@phx_target}
        phx-value-id={@phx_value_id}
      />
      <span :if={@label} class="text-sm">{@label}</span>
    </label>
    """
  end

  @impl true
  def date_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn ->
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:id, fn -> nil end)
      |> assign_new(:min, fn -> nil end)
      |> assign_new(:max, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
      />
      <input
        type="date"
        id={@id}
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && "bg-gray-100 cursor-not-allowed"]}
      />
    </div>
    """
  end

  @impl true
  def datetime_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn ->
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)

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
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && "bg-gray-100 cursor-not-allowed"]}
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
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500"
      end)
      |> assign_new(:step, fn -> "any" end)
      |> assign(:placeholder, placeholder)
      |> assign_new(:min, fn -> nil end)
      |> assign_new(:max, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)

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
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && "bg-gray-100 cursor-not-allowed"]}
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
    include:
      ~w(phx-click phx-target phx-value-id phx-value-event phx-value-values data-confirm disabled)

  @impl true
  def button(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> button_class(assigns[:variant]) end)
      |> assign_new(:icon, fn -> button_icon(assigns[:variant]) end)

    ~H"""
    <button type={@type} class={@class} {@rest}>
      <.render_icon :if={@icon} name={@icon} class="w-4 h-4 inline-block mr-1" />
      {@label}
    </button>
    """
  end

  attr :variant, :atom, default: :default

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
      |> assign_new(:message, fn -> "No records found" end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:action_label, fn -> nil end)
      |> assign_new(:action_path, fn -> nil end)
      |> assign_new(:action_icon, fn -> nil end)

    ~H"""
    <div class="py-12 text-center">
      <div :if={@icon} class="mb-4">
        <.render_icon name={@icon} class="w-12 h-12 mx-auto text-gray-400" />
      </div>
      <p class="text-gray-500 text-lg">{@message}</p>
      <a
        :if={@action_path && @action_label}
        href={@action_path}
        class="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition-colors"
      >
        <.render_icon :if={@action_icon} name={@action_icon} class="w-4 h-4" />
        {@action_label}
      </a>
    </div>
    """
  end

  @impl true
  def error_state(assigns) do
    assigns =
      assigns
      |> assign_new(:message, fn -> "Error loading data" end)
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
          phx-click="reload"
          phx-target={@target}
          class="px-4 py-2 bg-red-100 text-red-700 rounded hover:bg-red-200"
        >
          {@retry_label}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Render a date range container with two date inputs and separator.

  ## Assigns
    * `:class` - Container CSS class (default: "flex items-center gap-2")
    * `:separator_class` - Separator text CSS class (default: "text-gray-500")
    * `:from_input` - Pre-rendered from date input
    * `:to_input` - Pre-rendered to date input
  """
  @impl true
  def date_range_container(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "flex items-center gap-2" end)
      |> assign_new(:separator_class, fn -> "text-gray-500" end)

    ~H"""
    <div class={@class}>
      {@from_input}
      <span class={@separator_class}>to</span>
      {@to_input}
    </div>
    """
  end

  attr :variant, :atom, default: :default
  attr :external, :boolean, default: false

  @impl true
  def nav_link(assigns) do
    variant = assigns[:variant] || :default
    external = assigns[:external] || false

    assigns =
      assigns
      |> assign_new(:class, fn -> nav_link_class(variant) end)
      |> assign_new(:icon, fn -> nav_link_icon(variant) end)
      |> assign(:external, external)

    if external do
      ~H"""
      <a href={@navigate} target="_blank" rel="noopener noreferrer" class={@class}>
        <.render_icon :if={@icon} name={@icon} class="w-4 h-4 inline-block mr-1" />
        {@label}
        <.render_icon name="hero-arrow-top-right-on-square" class="w-3 h-3 inline ml-1" />
      </a>
      """
    else
      ~H"""
      <.link navigate={@navigate} class={@class}>
        <.render_icon :if={@icon} name={@icon} class="w-4 h-4 inline-block mr-1" />
        {@label}
      </.link>
      """
    end
  end

  @impl true
  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm text-left">
        {render_slot(@inner_block)}
      </table>
    </div>
    """
  end

  @impl true
  def table_header(assigns) do
    ~H"""
    <thead class="text-xs text-gray-700 uppercase bg-gray-50">
      <tr>
        {render_slot(@inner_block)}
      </tr>
    </thead>
    """
  end

  @impl true
  def th(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "px-6 py-3" end)
      |> assign_new(:sortable, fn -> false end)
      |> assign_new(:field, fn -> nil end)
      |> assign_new(:target, fn -> nil end)

    ~H"""
    <th
      class={[@class, @sortable && "cursor-pointer hover:bg-gray-100 select-none"]}
      phx-click={@sortable && "sort"}
      phx-value-field={@sortable && @field}
      phx-target={@sortable && @target}
    >
      {render_slot(@inner_block)}
    </th>
    """
  end

  @impl true
  def tr(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "bg-white border-b hover:bg-gray-50" end)

    ~H"""
    <tr id={@id} class={@class}>
      {render_slot(@inner_block)}
    </tr>
    """
  end

  @impl true
  def td(assigns) do
    assigns = assign_new(assigns, :class, fn -> "px-6 py-4" end)

    ~H"""
    <td class={@class}>
      {render_slot(@inner_block)}
    </td>
    """
  end

  @impl true
  def dropdown(assigns) do
    assigns =
      assigns
      |> assign_new(:icon, fn -> "hero-ellipsis-vertical" end)
      |> assign(:menu_id, "dropdown-#{System.unique_integer([:positive])}")

    ~H"""
    <div class="relative inline-block text-left">
      <button
        type="button"
        class="p-2 hover:bg-gray-100 rounded"
        phx-click={
          JS.toggle(
            to: "##{@menu_id}",
            in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
            out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
          )
        }
      >
        <.render_icon name={@icon} class="w-5 h-5" />
      </button>
      <div
        id={@menu_id}
        class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg ring-1 ring-black ring-opacity-5 z-10 py-1"
        phx-click-away={
          JS.hide(
            to: "##{@menu_id}",
            transition: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
          )
        }
      >
        <div class="flex flex-col">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Render empty cell value (nil/missing data).

  ## Assigns
    * `:text` - Text to show (default: "-")
    * `:class` - CSS class (default: "text-gray-400")
  """
  @impl true
  def cell_empty(assigns) do
    assigns =
      assigns
      |> assign_new(:text, fn -> "-" end)
      |> assign_new(:class, fn -> "text-gray-400" end)

    ~H"""
    <span class={@class}>{@text}</span>
    """
  end

  @doc """
  Render text cell value.

  ## Assigns
    * `:text` - The text to display
    * `:title` - Optional tooltip (for truncated text)
    * `:class` - CSS class
    * `:suffix` - Optional suffix text (with different styling)
    * `:suffix_class` - CSS class for suffix (default: "text-gray-500")
  """
  @impl true
  def cell_text(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:suffix, fn -> nil end)
      |> assign_new(:suffix_class, fn -> "text-gray-500" end)

    ~H"""
    <span class={@class} title={@title}>
      {@text}<span :if={@suffix} class={@suffix_class}>{@suffix}</span>
    </span>
    """
  end

  @doc """
  Render number cell value.

  ## Assigns
    * `:value` - The formatted number string
    * `:prefix` - Prefix (e.g., "$")
    * `:suffix` - Suffix (e.g., "%")
    * `:class` - CSS class (default: "tabular-nums")
  """
  @impl true
  def cell_number(assigns) do
    assigns =
      assigns
      |> assign_new(:prefix, fn -> "" end)
      |> assign_new(:suffix, fn -> "" end)
      |> assign_new(:class, fn -> "tabular-nums" end)

    ~H"""
    <span class={@class}>{@prefix}{@value}{@suffix}</span>
    """
  end

  @doc """
  Render date cell value.

  ## Assigns
    * `:formatted` - The formatted date string
    * `:class` - CSS class
  """
  @impl true
  def cell_date(assigns) do
    assigns = assign_new(assigns, :class, fn -> nil end)

    ~H"""
    <span class={@class}>{@formatted}</span>
    """
  end

  @doc """
  Render datetime cell value.

  ## Assigns
    * `:formatted` - The formatted datetime string
    * `:iso` - ISO 8601 string for datetime attribute
    * `:variant` - :default or :relative
    * `:class` - CSS class
  """
  @impl true
  def cell_datetime(assigns) do
    variant = assigns[:variant] || :default

    assigns =
      assigns
      |> assign_new(:class, fn -> cell_datetime_class(variant) end)
      |> assign_new(:iso, fn -> nil end)

    ~H"""
    <time datetime={@iso} class={@class}>{@formatted}</time>
    """
  end

  @doc """
  Render code/monospace cell value (for UUID, etc.).

  ## Assigns
    * `:value` - The value to display
    * `:title` - Optional tooltip (for truncated values)
    * `:class` - CSS class (default: "text-xs font-mono")
  """
  @impl true
  def cell_code(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "text-xs font-mono" end)
      |> assign_new(:title, fn -> nil end)

    ~H"""
    <code class={@class} title={@title}>{@value}</code>
    """
  end

  @doc """
  Render array/list container.

  ## Assigns
    * `:class` - Container CSS class (default: "flex flex-wrap gap-1")
    * `:badges` - List of pre-rendered badge elements (for badge mode)
    * `:remaining` - Pre-rendered remaining count element
    * `:inner_block` - Slot for array items (alternative to badges)
  """
  @impl true
  def cell_array(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "flex flex-wrap gap-1" end)
      |> assign_new(:badges, fn -> nil end)
      |> assign_new(:remaining, fn -> nil end)

    ~H"""
    <div class={@class}>
      <%= if @badges do %>
        <%= for badge <- @badges do %>
          {badge}
        <% end %>
        {if @remaining, do: @remaining}
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </div>
    """
  end

  @doc """
  Render filter reset/clear button.

  ## Assigns
    * `:label` - Button label text
    * `:class` - CSS class
  """
  @impl true
  def filter_reset_button(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn -> "Clear filters" end)
      |> assign_new(:class, fn -> "text-sm text-gray-500 hover:text-gray-700 underline" end)

    ~H"""
    <button type="reset" name="reset" class={@class}>
      {@label}
    </button>
    """
  end

  @doc """
  Render archive status toggle.

  ## Assigns
    * `:archive_status` - Current status (:active or :archived)
    * `:myself` - LiveComponent target
    * `:active_label` - Label for active option
    * `:archived_label` - Label for archived option
    * `:status_label` - Label prefix
  """
  @impl true
  def archive_toggle(assigns) do
    assigns =
      assigns
      |> assign_new(:status_label, fn -> "Status" end)
      |> assign_new(:active_label, fn -> "Active" end)
      |> assign_new(:archived_label, fn -> "Archived" end)
      |> assign_new(:class, fn ->
        "rounded-md border-gray-300 text-sm focus:border-blue-500 focus:ring-blue-500"
      end)

    ~H"""
    <form phx-change="archive_filter" phx-target={@myself} class="flex items-center gap-2">
      <label class="text-sm font-medium text-gray-700">
        {@status_label}:
      </label>
      <select name="status" class={@class}>
        <option value="active" selected={@archive_status == :active}>
          {@active_label}
        </option>
        <option value="archived" selected={@archive_status == :archived}>
          {@archived_label}
        </option>
      </select>
    </form>
    """
  end

  @doc """
  Render bulk actions bar container.

  ## Assigns
    * `:select_all` - Whether all are selected
    * `:selected_count` - Number of selected items
    * `:excluded_count` - Number of excluded items
    * `:inner_block` - Slot for action buttons
  """
  @impl true
  def bulk_action_bar(assigns) do
    assigns =
      assigns
      |> assign_new(:all_selected_label, fn -> "All selected" end)
      |> assign_new(:all_except_label, fn -> "All except %{count} selected" end)
      |> assign_new(:selected_label, fn -> "%{count} selected" end)
      |> assign_new(:clear_label, fn -> "Clear selection" end)
      |> assign_new(:class, fn ->
        "bg-blue-50 border border-blue-200 rounded p-3 mb-4 flex items-center gap-4"
      end)

    ~H"""
    <div class={@class}>
      <span class="text-sm font-medium">
        <%= cond do %>
          <% @select_all and @excluded_count == 0 -> %>
            {@all_selected_label}
          <% @select_all and @excluded_count > 0 -> %>
            {String.replace(@all_except_label, "%{count}", to_string(@excluded_count))}
          <% true -> %>
            {String.replace(@selected_label, "%{count}", to_string(@selected_count))}
        <% end %>
      </span>
      <div class="flex gap-2">
        {render_slot(@inner_block)}
      </div>
      <button
        type="button"
        phx-click={clear_selection_js(@myself)}
        class="ml-auto text-sm text-gray-500 hover:text-gray-700"
      >
        {@clear_label}
      </button>
    </div>
    """
  end

  @doc """
  Render individual bulk action button.

  ## Assigns
    * `:action` - The action map
    * `:myself` - LiveComponent target
  """
  @impl true
  def bulk_action_button(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "px-3 py-1 text-sm bg-white border rounded hover:bg-gray-50" end)

    ~H"""
    <button
      type="button"
      phx-click="bulk_action"
      phx-value-action={@action.name}
      phx-target={@myself}
      class={@class}
      data-confirm={@action.confirm}
    >
      {(@action.ui && @action.ui.label) || Phoenix.Naming.humanize(@action.name)}
    </button>
    """
  end

  @doc """
  Render pagination container with page info.

  ## Assigns
    * `:page` - Current page
    * `:total_pages` - Total pages
    * `:total_count` - Total record count
    * `:show_total` - Whether to show total info
    * `:page_info_format` - Format string for page info
    * `:inner_block` - Slot for pagination buttons
  """
  @impl true
  def pagination_container(assigns) do
    assigns =
      assigns
      |> assign_new(:show_total, fn -> true end)
      |> assign_new(:page_info_format, fn -> "Page {page} of {total}" end)

    ~H"""
    <div class="mt-4 flex items-center justify-center gap-2">
      {render_slot(@inner_block)}
    </div>
    <div :if={@show_total} class="mt-2 text-center text-sm text-gray-600">
      {format_page_info(@page_info_format, @page, @total_pages, @total_count)}
    </div>
    """
  end

  @doc """
  Render pagination nav button (prev/next/first/last).

  ## Assigns
    * `:label` - Button label
    * `:disabled` - Whether button is disabled
    * `:event` - Event name to trigger
    * `:page` - Page value (for go_to_page)
    * `:myself` - LiveComponent target
  """
  @impl true
  def pagination_nav_button(assigns) do
    assigns =
      assigns
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:class, fn -> "px-3 py-1 border rounded transition-colors" end)

    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-value-page={@page}
      phx-target={@myself}
      disabled={@disabled}
      class={[
        @class,
        @disabled && "opacity-50 cursor-not-allowed",
        !@disabled && "hover:bg-gray-50"
      ]}
    >
      {@label}
    </button>
    """
  end

  @doc """
  Render pagination page number button.

  ## Assigns
    * `:page_num` - Page number to display
    * `:current_page` - Currently active page
    * `:disabled` - Whether button is disabled
    * `:myself` - LiveComponent target
  """
  @impl true
  def pagination_page_button(assigns) do
    assigns =
      assigns
      |> assign_new(:disabled, fn -> false end)

    is_active = assigns.page_num == assigns.current_page

    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <button
      type="button"
      phx-click="go_to_page"
      phx-value-page={@page_num}
      phx-target={@myself}
      disabled={@disabled}
      class={[
        "px-3 py-1 border rounded transition-colors",
        @is_active && "bg-blue-500 text-white border-blue-500",
        !@is_active && "hover:bg-gray-50"
      ]}
    >
      {@page_num}
    </button>
    """
  end

  @doc """
  Render a loading state.

  This is an optional function that templates can use for customizable loading UI.
  Supports `:spinner` (default), `:skeleton`, and `:dots` types.

  ## Assigns

    * `:type` - Loading type: `:initial`, `:reset`, `:more` (default: `:initial`)
    * `:style` - Loading style: `:spinner`, `:skeleton`, `:dots` (default: `:spinner`)
    * `:text` - Optional loading text
    * `:class` - Additional CSS classes

  ## Examples

      <.loading type={:initial} />
      <.loading type={:reset} style={:skeleton} />
  """
  def loading(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> :initial end)
      |> assign_new(:style, fn -> :spinner end)
      |> assign_new(:text, fn -> nil end)
      |> assign_new(:class, fn -> nil end)

    case assigns.style do
      :skeleton -> render_skeleton_loading(assigns)
      :dots -> render_dots_loading(assigns)
      _ -> render_spinner_loading(assigns)
    end
  end

  @doc """
  Render loading state.

  ## Assigns
    * `:type` - Loading type (:initial, :reset, :more)
    * `:text` - Loading text
    * `:style` - Style (:spinner, :skeleton, :dots)
  """
  @impl true
  def loading_state(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> :initial end)
      |> assign_new(:style, fn -> :spinner end)
      |> assign_new(:text, fn -> "Loading..." end)
      |> assign_new(:class, fn -> nil end)

    case assigns.style do
      :skeleton -> render_skeleton_loading(assigns)
      :dots -> render_dots_loading(assigns)
      _ -> render_spinner_loading(assigns)
    end
  end

  @doc """
  Render template switcher container with buttons.

  ## Assigns
    * `:switchable_templates` - List of template modules
    * `:current_template` - Currently active template module
    * `:myself` - LiveComponent target
  """
  @impl true
  def template_switcher(assigns) do
    ~H"""
    <div :if={length(@switchable_templates) > 1} class="flex gap-1 border rounded p-1">
      <.template_switcher_button
        :for={template <- @switchable_templates}
        template={template}
        current_template={@current_template}
        myself={@myself}
      />
    </div>
    """
  end

  @doc """
  Render template switcher button.

  ## Assigns
    * `:template` - Template module
    * `:current_template` - Currently active template module
    * `:myself` - LiveComponent target
  """
  @impl true
  def template_switcher_button(assigns) do
    is_active = assigns.current_template.name() == assigns.template.name()
    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <button
      type="button"
      phx-click="switch_template"
      phx-value-template={@template.name()}
      phx-target={@myself}
      class={[
        "p-2 rounded transition-colors",
        @is_active && "bg-gray-200",
        !@is_active && "hover:bg-gray-100"
      ]}
      title={@template.label()}
    >
      <span class={@template.icon()}></span>
    </button>
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
      |> assign_new(:class, fn ->
        "flex items-center justify-between pt-6 border-t border-gray-200"
      end)

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
            @can_advance &&
              "bg-blue-600 hover:bg-blue-700 focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
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
    <label class={@class} phx-drop-target={@upload_ref}>
      <.render_icon name="hero-cloud-arrow-up" class="w-10 h-10 text-gray-400 mb-3" />
      <p class="text-sm text-gray-600">
        <span class="font-semibold text-blue-600">Click to upload</span> or drag and drop
      </p>
      <p :if={@accept} class="mt-1 text-xs text-gray-500">
        {format_accept(@accept)}
      </p>
      <p :if={@max_entries > 1} class="mt-1 text-xs text-gray-500">
        Up to {@max_entries} files
      </p>
      {render_slot(@inner_block)}
    </label>
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
      |> assign_new(:class, fn ->
        "w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-blue-600"
      end)
      |> assign_new(:show_value, fn -> false end)
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <div class="flex items-center gap-3">
      <input
        type="range"
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        step={@step}
        disabled={@disabled}
        class={[@class, @disabled && "cursor-not-allowed"]}
      />
      <span
        :if={@show_value}
        class="text-sm font-medium text-gray-700 tabular-nums min-w-[3ch] text-right"
      >
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
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <textarea
      name={@name}
      placeholder={@placeholder}
      rows={@rows}
      disabled={@disabled}
      class={[@class, @disabled && "bg-gray-100 cursor-not-allowed"]}
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
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <textarea
      name={@name}
      rows={@rows}
      disabled={@disabled}
      class={[@class, @disabled && "bg-gray-100 cursor-not-allowed"]}
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
  def string_list_input(assigns) do
    assigns =
      assigns
      |> assign_new(:items, fn -> [] end)
      |> assign_new(:field_name, fn -> "" end)
      |> assign_new(:add_label, fn -> "+ Add" end)
      |> assign_new(:remove_label, fn -> "Remove" end)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:target, fn -> nil end)
      |> assign_new(:class, fn -> "space-y-2" end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:input_class, fn ->
        "flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
      end)
      |> assign(:items_with_index, Enum.with_index(assigns[:items] || []))

    ~H"""
    <div id={"string-list-#{@field_name}"} class={@class}>
      <%!-- Hidden input ensures field present in params when list is empty --%>
      <input type="hidden" name={"form[#{@field_name}][]"} value="" />

      <%= for {item, idx} <- @items_with_index do %>
        <div class="flex items-center gap-2" id={"string-list-#{@field_name}-#{idx}"}>
          <input
            type="text"
            name={"form[#{@field_name}][]"}
            value={item}
            placeholder={@placeholder}
            disabled={@disabled}
            class={[@input_class, @disabled && "bg-gray-100 cursor-not-allowed"]}
          />
          <button
            :if={!@disabled}
            type="button"
            phx-click="remove_list_item"
            phx-value-field={@field_name}
            phx-value-index={idx}
            phx-target={@target}
            class="inline-flex items-center p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors"
            title={@remove_label}
          >
            <.render_icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>
      <% end %>

      <button
        :if={!@disabled}
        type="button"
        phx-click="add_list_item"
        phx-value-field={@field_name}
        phx-target={@target}
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors"
      >
        <.render_icon name="hero-plus" class="w-4 h-4" />
        {@add_label}
      </button>
    </div>
    """
  end

  @impl true
  def combobox(assigns) do
    normalized = normalize_options(assigns[:options] || [])

    assigns =
      assigns
      |> assign(:options, normalized)
      |> assign_new(:class, fn ->
        "rounded border-gray-300 px-3 py-2 text-sm focus:ring-blue-500 focus:border-blue-500 w-full"
      end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:phx_debounce, fn -> 300 end)
      |> assign_new(:field_name, fn -> nil end)
      |> assign_new(:target, fn -> nil end)
      |> assign(:dropdown_id, "combobox-dropdown-#{assigns[:field_name] || assigns[:name]}")

    ~H"""
    <div class="relative" phx-click-away={JS.hide(to: "##{@dropdown_id}")}>
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
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && "bg-gray-100 cursor-not-allowed"]}
        phx-debounce={@phx_debounce}
        phx-click={JS.show(to: "##{@dropdown_id}")}
        phx-focus={JS.show(to: "##{@dropdown_id}")}
        phx-keyup={JS.show(to: "##{@dropdown_id}")}
        autocomplete="off"
      />
      <div
        id={@dropdown_id}
        class="hidden absolute z-50 mt-1 w-full max-h-60 overflow-auto rounded-md bg-white shadow-lg ring-1 ring-black/5"
      >
        <%= for {label, value} <- @options do %>
          <button
            type="button"
            phx-click={
              JS.push("combobox_select",
                value: %{field: to_string(@field_name), value: value},
                target: @target
              )
              |> JS.hide(to: "##{@dropdown_id}")
            }
            class="block w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-blue-50 hover:text-blue-700"
          >
            {label}
          </button>
        <% end %>
      </div>
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

  @impl true
  def upload_file_input(assigns) do
    assigns =
      assigns
      |> assign_new(:accept, fn -> nil end)
      |> assign_new(:max_entries, fn -> 1 end)
      |> assign_new(:class, fn ->
        "block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
      end)

    ~H"""
    <div class="space-y-2">
      <div class={@class}>
        {render_slot(@inner_block)}
      </div>
      <p :if={@accept} class="text-xs text-gray-500">
        Accepted: {format_accept(@accept)}
      </p>
      <p :if={@max_entries > 1} class="text-xs text-gray-500">
        Up to {@max_entries} files
      </p>
    </div>
    """
  end

  @impl true
  def upload_existing_file(assigns) do
    file = assigns[:file] || %{}

    assigns =
      assigns
      |> assign_new(:class, fn ->
        "flex items-center gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200 group"
      end)
      |> assign_new(:filename, fn -> file[:filename] || file[:name] || "File" end)
      |> assign_new(:url, fn -> file[:url] end)
      |> assign_new(:size, fn -> file[:size] end)
      |> assign_new(:format, fn -> file[:format] end)
      |> assign_new(:is_image, fn -> image_file?(file) end)
      |> assign_new(:phx_target, fn -> nil end)

    ~H"""
    <div class={@class}>
      <div class="w-14 h-14 bg-gray-200 rounded-md overflow-hidden flex-shrink-0">
        <%= if @is_image && @url do %>
          <img src={@url} alt={@filename} class="w-full h-full object-cover" />
        <% else %>
          <div class="flex items-center justify-center w-full h-full">
            <.render_icon name={file_type_icon(@format)} class="w-7 h-7 text-gray-400" />
          </div>
        <% end %>
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium text-gray-900 truncate">{@filename}</p>
        <p :if={@size || @format} class="text-xs text-gray-500">
          <span :if={@format}>{@format}</span>
          <span :if={@size && @format} class="mx-1">&middot;</span>
          <span :if={@size}>{format_filesize(@size)}</span>
        </p>
      </div>
      <button
        type="button"
        phx-click="delete_existing_file"
        phx-value-upload={@upload_name}
        phx-value-file-id={@file_id}
        phx-target={@phx_target}
        class="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors opacity-0 group-hover:opacity-100 flex-shrink-0"
        title="Remove file"
      >
        <.render_icon name="hero-x-mark" class="w-5 h-5" />
      </button>
    </div>
    """
  end

  defp image_file?(%{type: "images"}), do: true
  defp image_file?(%{type: :images}), do: true

  defp image_file?(%{format: fmt}) when is_binary(fmt) do
    String.downcase(fmt) in ~w(jpg jpeg png gif webp svg bmp ico tiff)
  end

  defp image_file?(%{filename: name}) when is_binary(name) do
    ext = name |> Path.extname() |> String.downcase() |> String.trim_leading(".")
    ext in ~w(jpg jpeg png gif webp svg bmp ico tiff)
  end

  defp image_file?(_), do: false

  defp file_type_icon(nil), do: "hero-document"

  defp file_type_icon(fmt) when is_binary(fmt) do
    case String.downcase(fmt) do
      f when f in ~w(pdf) -> "hero-document-text"
      f when f in ~w(mp4 webm mov avi) -> "hero-film"
      f when f in ~w(doc docx txt csv) -> "hero-document-text"
      f when f in ~w(xls xlsx) -> "hero-table-cells"
      f when f in ~w(ppt pptx) -> "hero-presentation-chart-bar"
      _ -> "hero-document"
    end
  end

  defp file_type_icon(_), do: "hero-document"

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

  defp button_class(:primary),
    do:
      "px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md shadow-sm hover:bg-blue-700 focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"

  defp button_class(:danger),
    do:
      "px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md shadow-sm hover:bg-red-700 focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"

  defp button_class(:secondary),
    do:
      "px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 transition-colors"

  defp button_class(_), do: "px-3 py-2 text-sm rounded hover:bg-gray-100 transition-colors"

  defp button_icon(_variant), do: nil

  defp nav_link_class(:edit), do: "text-indigo-600 hover:text-indigo-800"
  defp nav_link_class(:show), do: "text-blue-600 hover:text-blue-800"
  defp nav_link_class(:external), do: "text-blue-600 hover:text-blue-800 hover:underline"
  defp nav_link_class(_), do: "text-gray-600 hover:text-gray-800"

  defp nav_link_icon(:edit), do: "hero-pencil"
  defp nav_link_icon(:show), do: "hero-eye"
  defp nav_link_icon(_), do: nil

  defp icon_name(:boolean_true), do: "hero-check"
  defp icon_name(:boolean_false), do: "hero-x-mark"
  defp icon_name(_), do: nil

  defp icon_class(:boolean_true), do: "w-5 h-5 text-green-600"
  defp icon_class(:boolean_false), do: "w-5 h-5 text-red-600"
  defp icon_class(_), do: "w-5 h-5"

  defp cell_datetime_class(:relative), do: "text-gray-600"
  defp cell_datetime_class(_), do: nil

  defp clear_selection_js(myself) do
    JS.push("clear_selection", target: myself)
    |> Shared.uncheck_all()
  end

  defp format_page_info(format, page, total_pages, total_count) do
    format
    |> String.replace("{page}", to_string(page))
    |> String.replace("{total}", to_string(total_pages || "?"))
    |> String.replace("{count}", to_string(total_count || ""))
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

  defp render_spinner_loading(assigns) do
    ~H"""
    <div class={["py-12 text-center", @class]}>
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-blue-500 border-t-transparent">
      </div>
      <p :if={@text} class="mt-2 text-gray-500">{@text}</p>
      <p :if={!@text} class="mt-2 text-gray-500">Loading...</p>
    </div>
    """
  end

  defp render_skeleton_loading(assigns) do
    ~H"""
    <div class={["space-y-3 p-4", @class]}>
      <div class="animate-pulse space-y-4">
        <div class="flex items-center space-x-4">
          <div class="rounded-full bg-gray-200 h-10 w-10"></div>
          <div class="flex-1 space-y-2">
            <div class="h-4 bg-gray-200 rounded w-3/4"></div>
            <div class="h-4 bg-gray-200 rounded w-1/2"></div>
          </div>
        </div>
        <div class="h-4 bg-gray-200 rounded"></div>
        <div class="h-4 bg-gray-200 rounded w-5/6"></div>
        <div class="h-4 bg-gray-200 rounded w-4/6"></div>
        <div class="flex items-center space-x-4 pt-2">
          <div class="rounded-full bg-gray-200 h-10 w-10"></div>
          <div class="flex-1 space-y-2">
            <div class="h-4 bg-gray-200 rounded w-2/3"></div>
            <div class="h-4 bg-gray-200 rounded w-1/3"></div>
          </div>
        </div>
        <div class="h-4 bg-gray-200 rounded w-full"></div>
        <div class="h-4 bg-gray-200 rounded w-3/4"></div>
      </div>
    </div>
    """
  end

  defp render_dots_loading(assigns) do
    ~H"""
    <div class={["py-12 text-center", @class]}>
      <div class="flex justify-center space-x-2">
        <div class="w-3 h-3 bg-blue-500 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
        <div class="w-3 h-3 bg-blue-500 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
        <div class="w-3 h-3 bg-blue-500 rounded-full animate-bounce"></div>
      </div>
      <p :if={@text} class="mt-4 text-gray-500">{@text}</p>
      <p :if={!@text} class="mt-4 text-gray-500">Loading...</p>
    </div>
    """
  end

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

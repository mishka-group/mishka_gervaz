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

  @disabled_class "cursor-not-allowed bg-[#f6f5f2] text-[#8a877f]"

  @doc """
  The classes every field of this adapter wears when it is disabled or readonly.

  Call it from an adapter that overrides one input, to switch it off the way its neighbours are.
  """
  @spec disabled_class() :: String.t()
  def disabled_class, do: @disabled_class

  @impl true
  def text_input(assigns) do
    placeholder =
      assigns[:placeholder] ||
        if assigns[:placeholder_label], do: "Search #{assigns[:placeholder_label]}..."

    search? = assigns[:search] == true

    assigns =
      assigns
      |> assign(:search, search?)
      |> assign_new(:class, fn -> input_class(search?) end)
      |> assign_new(:phx_debounce, fn ->
        case Map.fetch(assigns, :"phx-debounce") do
          {:ok, value} -> value
          :error -> 300
        end
      end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:search, fn -> false end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:autocomplete, fn -> nil end)
      |> assign(:placeholder, placeholder)

    ~H"""
    <div class="relative">
      <svg
        :if={@search}
        class="pointer-events-none absolute left-[13px] top-1/2 size-[15px] -translate-y-1/2 text-[#a8a5a0]"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.9"
        stroke-linecap="round"
        aria-hidden="true"
      >
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-3.2-3.2" />
      </svg>
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        disabled={@disabled}
        readonly={@readonly}
        autocomplete={@autocomplete}
        class={[
          @class,
          "placeholder:text-[#a8a5a0]",
          @search && "pl-[38px]!",
          (@disabled || @readonly) && disabled_class()
        ]}
        phx-debounce={@phx_debounce}
      />
    </div>
    """
  end

  @impl true
  def password_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:phx_debounce, fn ->
        case Map.fetch(assigns, :"phx-debounce") do
          {:ok, value} -> value
          :error -> 300
        end
      end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:autocomplete, fn -> "new-password" end)

    ~H"""
    <input
      type="password"
      name={@name}
      value={@value}
      placeholder={@placeholder}
      disabled={@disabled}
      readonly={@readonly}
      autocomplete={@autocomplete}
      class={[@class, (@disabled || @readonly) && disabled_class()]}
      phx-debounce={@phx_debounce}
    />
    """
  end

  @doc false
  def input_class(search?) do
    base =
      if search?,
        do: "h-[42px] bg-white px-[13px] text-[12.5px] text-[#3a382f]",
        else: "h-11 bg-[#faf9f6] px-[14px] text-[13px] text-[#1b1a18]"

    "w-full rounded-[11px] border border-[#ecebe6] font-medium outline-none transition-shadow " <>
      "focus:border-[#c3c1f0] focus:bg-white focus:shadow-[0_0_0_3px_rgba(91,87,214,0.1)] " <>
      base
  end

  @doc """
  The same field as `input_class/1`, for a control that grows down the page instead of holding one
  line. Everything but the height is shared; `rows` decides the height, so `extra` carries it.
  """
  @spec multiline_class(String.t()) :: String.t()
  def multiline_class(extra) do
    "w-full rounded-[11px] border border-[#ecebe6] bg-[#faf9f6] px-[14px] py-[11px] text-[13px] " <>
      extra <>
      "font-medium leading-[1.55] text-[#1b1a18] outline-none transition-shadow " <>
      "placeholder:text-[#a8a5a0] focus:border-[#c3c1f0] focus:bg-white " <>
      "focus:shadow-[0_0_0_3px_rgba(91,87,214,0.1)]"
  end

  @impl true
  def select(assigns) do
    normalized = normalize_grouped_options(assigns[:options] || [])

    assigns =
      assigns
      |> assign(:options, normalized)
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:prompt, fn -> "All" end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0] pointer-events-none"
      />
      <select
        name={@name}
        disabled={@disabled}
        class={[
          @class,
          "cursor-pointer appearance-none pr-[32px]!",
          @icon && "pl-9",
          @disabled && disabled_class()
        ]}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        <%= for entry <- @options do %>
          <%= case entry do %>
            <% {:group, group_label, opts} -> %>
              <optgroup label={group_label}>
                <option
                  :for={{label, value} <- opts}
                  value={value}
                  selected={to_string(@value) == to_string(value)}
                >
                  {label}
                </option>
              </optgroup>
            <% {:option, label, value} -> %>
              <option value={value} selected={to_string(@value) == to_string(value)}>{label}</option>
          <% end %>
        <% end %>
      </select>
      <svg
        class="pointer-events-none absolute right-[11px] top-1/2 size-[13px] -translate-y-1/2 text-[#a8a5a0]"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2.2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d="m6 9 6 6 6-6" />
      </svg>
    </div>
    """
  end

  # `{group_label, [opts]}` → optgroup; anything else → a flat option.
  defp normalize_grouped_options(options) when is_list(options) do
    Enum.map(options, fn
      {group_label, opts} when is_list(opts) ->
        {:group, to_string(group_label), normalize_options(opts)}

      other ->
        [{label, value}] = normalize_options([other])
        {:option, label, value}
    end)
  end

  defp normalize_grouped_options(_), do: []

  @doc """
  Single-select dropdown with search support for relation filters.

  `multi_select` adapted for single selection. Whatever is currently selected is merged in from
  `:selected_options` and sorted to the top of the list, so a value restored from the URL is shown
  even when it is not on the loaded page of options.
  """
  @impl true
  def search_select(assigns) do
    options = normalize_options(assigns[:options] || [])
    current_value = assigns[:value] || ""
    selected_options = normalize_options(assigns[:selected_options] || [])
    disabled = assigns[:disabled] || false

    display_options =
      if current_value != "" do
        (selected_options ++ options)
        |> Enum.uniq_by(fn {_, v} -> to_string(v) end)
        |> Enum.split_with(fn {_, v} -> to_string(v) == to_string(current_value) end)
        |> then(fn {selected, rest} -> selected ++ rest end)
      else
        options
      end

    display_label =
      if current_value != "" do
        (selected_options ++ options)
        |> Enum.find(fn {_l, v} -> to_string(v) == to_string(current_value) end)
        |> case do
          {label, _} -> label
          nil -> current_value
        end
      else
        nil
      end

    assigns =
      assigns
      |> assign(:options, options)
      |> assign(:display_options, display_options)
      |> assign(:current_value, current_value)
      |> assign(:disabled, disabled)
      |> assign(:display_label, display_label)
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:placeholder, fn -> "Search..." end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:loading?, fn -> false end)
      |> assign_new(:dropdown_open?, fn -> false end)
      |> assign_new(:min_chars, fn -> 2 end)
      |> assign_new(:debounce, fn -> 300 end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:filter_name, fn -> assigns[:name] end)
      |> assign_new(:table_id, fn -> nil end)
      |> assign_new(:myself, fn -> nil end)
      |> assign_new(:search_term, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"search-select-#{@table_id}-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <div class="relative">
        <.render_icon
          :if={@icon}
          name={@icon}
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0] pointer-events-none z-10"
        />
        <input
          type="text"
          name={"_search_#{@filter_name}"}
          value={if(@search_term not in [nil, ""], do: @search_term, else: @display_label || "")}
          placeholder={@placeholder}
          class={[
            @class,
            @icon && "pl-9",
            "w-full",
            @disabled && disabled_class()
          ]}
          disabled={@disabled}
          phx-debounce={if !@disabled, do: @debounce}
          phx-keyup={if !@disabled, do: "relation_search"}
          phx-focus={if !@disabled, do: "relation_focus"}
          phx-target={@myself}
          phx-value-filter={@filter_name}
          phx-value-min-chars={@min_chars}
          autocomplete="off"
        />
        <span
          :if={@loading? && !@disabled}
          class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 border-2 border-[#ecebe6] border-t-[#5b57d6] rounded-full animate-spin"
        />
      </div>

      <input type="hidden" name={@name} value={@current_value} />

      <div
        :if={@dropdown_open? && !@disabled}
        class="absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-[11px] border border-[#ecebe6] bg-white shadow-[0_10px_30px_-12px_rgba(30,28,24,0.25)]"
      >
        <div :if={@display_options == []} class="px-3 py-2 text-[12.5px] font-medium text-[#a8a5a0]">
          No records found
        </div>
        <button
          :for={{opt_label, opt_value} <- @display_options}
          type="button"
          class={[
            "w-full px-3 py-2 text-left text-[12.5px] font-medium text-[#3a382f] hover:bg-[#f7f6f3]",
            to_string(@current_value) == to_string(opt_value) && "bg-[#f2f1fc] text-[#4f4bcc]"
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
          class="w-full border-t border-[#f0efea] px-3 py-2 text-left text-[12.5px] font-semibold text-[#4f4bcc] hover:bg-[#f7f6f3]"
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
        (selected_options ++ options)
        |> Enum.uniq_by(fn {_, v} -> to_string(v) end)
        |> Enum.split_with(fn {_, v} -> to_string(v) == to_string(current_value) end)
        |> then(fn {selected, rest} -> selected ++ rest end)
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
        "rounded-[10px] border border-[#ecebe6] bg-[#faf9f6] px-3 py-2 text-[12.5px] outline-none focus:border-[#c3c1f0] focus:bg-white focus:shadow-[0_0_0_3px_rgba(91,87,214,0.1)]"
      end)
      |> assign_new(:placeholder, fn -> "Select..." end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:loading?, fn -> false end)
      |> assign_new(:dropdown_open?, fn -> false end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:filter_name, fn -> assigns[:name] end)
      |> assign_new(:table_id, fn -> nil end)
      |> assign_new(:myself, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"load-more-select-#{@table_id}-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <button
        type="button"
        class={[@class, "w-full text-left flex items-center justify-between cursor-pointer bg-white"]}
        phx-click="relation_focus"
        phx-target={@myself}
        phx-value-filter={@filter_name}
      >
        <span class={[!@selected_label && "text-[#a8a5a0]"]}>
          {@selected_label || @placeholder}
        </span>
        <span class="ml-2 text-[#a8a5a0]">
          <.render_icon
            name="hero-chevron-down"
            class={["w-4 h-4 transition-transform", @dropdown_open? && "rotate-180"]}
          />
        </span>
      </button>

      <input type="hidden" name={@name} value={@current_value} />

      <div
        :if={@dropdown_open?}
        class="absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-[11px] border border-[#ecebe6] bg-white shadow-[0_10px_30px_-12px_rgba(30,28,24,0.25)]"
      >
        <div :if={@display_options == []} class="px-3 py-2 text-[12.5px] font-medium text-[#a8a5a0]">
          No records found
        </div>
        <button
          :for={{opt_label, opt_value} <- @display_options}
          type="button"
          class={[
            "w-full px-3 py-2 text-left text-[12.5px] font-medium text-[#3a382f] hover:bg-[#f7f6f3]",
            to_string(@current_value) == to_string(opt_value) && "bg-[#f2f1fc] text-[#4f4bcc]"
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
          class="w-full border-t border-[#f0efea] px-3 py-2 text-left text-[12.5px] font-semibold text-[#4f4bcc] hover:bg-[#f7f6f3]"
        >
          Load more...
        </button>
      </div>

      <span
        :if={@loading?}
        class="absolute right-8 top-1/2 -translate-y-1/2 w-4 h-4 border-2 border-[#ecebe6] border-t-[#5b57d6] rounded-full animate-spin"
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
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:placeholder, fn -> "Search..." end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:loading?, fn -> false end)
      |> assign_new(:dropdown_open?, fn -> false end)
      |> assign_new(:min_chars, fn -> 2 end)
      |> assign_new(:debounce, fn -> 300 end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:filter_name, fn -> assigns[:name] end)
      |> assign_new(:table_id, fn -> nil end)
      |> assign_new(:myself, fn -> nil end)
      |> assign_new(:search_term, fn -> nil end)

    ~H"""
    <div
      class="relative"
      id={"multi-select-#{@table_id}-#{@filter_name}"}
      phx-click-away="relation_close_dropdown"
      phx-value-filter={@filter_name}
      phx-target={@myself}
    >
      <div class="relative">
        <.render_icon
          :if={@icon}
          name={@icon}
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0] pointer-events-none z-10"
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
          class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 border-2 border-[#ecebe6] border-t-[#5b57d6] rounded-full animate-spin"
        />
      </div>

      <input :for={val <- @selected} type="hidden" name={"#{@name}[]"} value={val} />

      <div
        :if={@dropdown_open?}
        class="absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-[11px] border border-[#ecebe6] bg-white shadow-[0_10px_30px_-12px_rgba(30,28,24,0.25)]"
      >
        <div :if={@display_options == []} class="px-3 py-2 text-[12.5px] font-medium text-[#a8a5a0]">
          No records found
        </div>
        <button
          :for={{label, value} <- @display_options}
          type="button"
          class={[
            "flex w-full items-center gap-2 px-3 py-2 text-left text-[12.5px] font-medium text-[#3a382f] hover:bg-[#f7f6f3]",
            selected?(value, @selected_set) && "bg-[#f2f1fc]"
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
          class="w-full border-t border-[#f0efea] px-3 py-2 text-left text-[12.5px] font-semibold text-[#4f4bcc] hover:bg-[#f7f6f3]"
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
      |> assign_new(:class, fn -> "size-4 cursor-pointer accent-[#5b57d6]" end)
      |> assign(:label, label)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:checked, fn -> false end)
      |> assign_new(:hidden_input, fn -> false end)
      |> assign(:phx_click, assigns[:"phx-click"])
      |> assign(:phx_target, assigns[:"phx-target"])
      |> assign(:phx_value_id, assigns[:"phx-value-id"])
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <label class="flex items-center gap-[9px]">
      <.render_icon :if={@icon} name={@icon} class="w-4 h-4 text-[#a8a5a0]" />
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
      <span :if={@label} class="text-[12.5px] font-semibold text-[#5c5a54]">{@label}</span>
    </label>
    """
  end

  @impl true
  def date_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:id, fn -> nil end)
      |> assign_new(:min, fn -> nil end)
      |> assign_new(:max, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:readonly, fn -> false end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0]"
      />
      <input
        type="date"
        id={@id}
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        disabled={@disabled}
        readonly={@readonly}
        class={[@class, @icon && "pl-9", (@disabled || @readonly) && disabled_class()]}
      />
    </div>
    """
  end

  @impl true
  def datetime_input(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:readonly, fn -> false end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0]"
      />
      <input
        type="datetime-local"
        name={@name}
        value={@value}
        disabled={@disabled}
        readonly={@readonly}
        class={[@class, @icon && "pl-9", (@disabled || @readonly) && disabled_class()]}
      />
    </div>
    """
  end

  @impl true
  def number_input(assigns) do
    placeholder = assigns[:placeholder] || assigns[:placeholder_label]

    assigns =
      assigns
      |> assign_new(:class, fn -> input_class(assigns[:search] == true) end)
      |> assign_new(:step, fn -> "any" end)
      |> assign(:placeholder, placeholder)
      |> assign_new(:min, fn -> nil end)
      |> assign_new(:max, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:readonly, fn -> false end)

    ~H"""
    <div class="relative">
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0]"
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
        readonly={@readonly}
        class={[@class, @icon && "pl-9", (@disabled || @readonly) && disabled_class()]}
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
      |> assign(:class, assigns[:class] || button_class(assigns[:variant]))
      |> assign(:icon, assigns[:icon] || button_icon(assigns[:variant]))
      |> assign_new(:label, fn -> nil end)

    ~H"""
    <button type={@type} class={@class} title={@label} {@rest}>
      <.render_icon :if={@icon} name={@icon} class="size-4" />
      <span :if={@label not in [nil, ""]} class="lbl">{@label}</span>
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
      |> assign_new(:variant, fn -> :tag end)
      |> assign_new(:dot, fn -> nil end)
      |> assign(:class, assigns[:class] || "bg-[#f6f5f2] text-[#6d6a63]")

    ~H"""
    <span class={[badge_shape(@variant), @class]}>
      <span :if={@dot} class={["size-[6px] rounded-full", @dot]}></span>
      {@label}
    </span>
    """
  end

  defp badge_shape(:pill),
    do:
      "inline-flex items-center gap-[6px] rounded-[20px] px-[11px] py-[4px] text-[10.5px] font-bold whitespace-nowrap"

  defp badge_shape(_),
    do:
      "inline-flex items-center rounded-[7px] px-[10px] py-[4px] text-[10.5px] font-bold whitespace-nowrap"

  @doc """
  Copy-to-clipboard button for a short value (e.g. an id). Requires the consuming app to register a
  `CopyToClipboard` JS hook; reads the text from `data-copy`.

  ## Assigns
    * `:value` - text placed on the clipboard
    * `:id` - DOM id (must be unique per row)
    * `:label` - tooltip / a11y title (default "Copy")
  """
  @impl true
  def copy_button(assigns) do
    assigns = assign_new(assigns, :label, fn -> "Copy" end)

    ~H"""
    <button
      type="button"
      id={@id}
      phx-hook="CopyToClipboard"
      phx-update="ignore"
      data-copy={@value}
      title={@label}
      class="grid place-items-center text-[#c3c0b8] transition-colors hover:text-[#8a877f] focus:outline-none"
    >
      <svg
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <rect x="9" y="9" width="12" height="12" rx="2" />
        <path d="M5 15V5a2 2 0 0 1 2-2h10" />
      </svg>
    </button>
    """
  end

  @doc """
  Bar-gauge cell: a numeric value drawn as `max` bars (the first `filled` in `color`, the rest muted)
  followed by the number. Used by the `:bars` column type.

  ## Assigns
    * `:value`  - the number shown after the bars
    * `:filled` - how many bars are lit
    * `:max`    - total number of bars
    * `:color`  - hex string (e.g. `"#1f9d6b"`) for the lit bars and the number

  The colour rides an inline `style`, not a Tailwind class: it comes from the column's `:scale`
  option, chosen per row from the cell's value, so there is no literal for Tailwind to find.
  """
  @impl true
  def cell_bars(assigns) do
    assigns = assign(assigns, :bars, bar_heights(assigns.max))

    ~H"""
    <div class="flex items-center gap-[9px]">
      <span class="flex h-[14px] items-end gap-[2px]">
        <span
          :for={{i, hclass} <- @bars}
          class={["w-[3px] rounded-[1px]", hclass, i > @filled && "bg-[#e0ded7]"]}
          style={i <= @filled && "background:#{@color}"}
        ></span>
      </span>
      <span class="font-['Space_Grotesk'] text-[12px] font-bold" style={"color:#{@color}"}>
        {@value}
      </span>
    </div>
    """
  end

  defp bar_heights(max) when max <= 1, do: [{1, "h-[14px]"}]

  defp bar_heights(max) do
    for i <- 1..max do
      px = round(5 + (14 - 5) * (i - 1) / (max - 1))
      {i, "h-[#{px}px]"}
    end
  end

  @impl true
  def spinner(assigns) do
    assigns = assign_new(assigns, :class, fn -> "w-6 h-6" end)

    ~H"""
    <div class={[
      "animate-spin rounded-full border-2 border-[#dcdbf5] border-t-[#5b57d6]",
      @class
    ]}>
    </div>
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
    <div class="flex flex-col items-center justify-center gap-3 rounded-[16px] border border-[#ecebe6] bg-white px-4 py-14 text-center">
      <span
        :if={@icon}
        class="grid size-[52px] place-items-center rounded-[14px] bg-[#f2f1ec] text-[#a8a5a0]"
      >
        <.render_icon name={@icon} class="size-6" />
      </span>
      <div class="font-['Space_Grotesk'] text-[14px] font-bold text-[#17161a]">{@message}</div>
      <a
        :if={@action_path && @action_label}
        href={@action_path}
        class="mt-1 inline-flex items-center gap-2 rounded-xl bg-[linear-gradient(140deg,#6d69e6,#4f4bcc)] px-[15px] py-[9px] text-[12.5px] font-bold text-white transition-opacity hover:opacity-95"
      >
        <.render_icon :if={@action_icon} name={@action_icon} class="size-4" />
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
    <div class="p-8 text-center">
      <.render_icon :if={@icon} name={@icon} class="mx-auto mb-4 size-12 text-[#c0392b]" />
      <div class="text-[14px] font-bold text-[#8f2c21]">{@message}</div>
      <div :if={@retry_label} class="mt-4">
        <button
          type="button"
          phx-click="reload"
          phx-target={@target}
          class="inline-flex h-9 items-center rounded-[10px] border border-[#f0dcd8] bg-[#fdf3f1] px-[13px] text-[12px] font-semibold text-[#c0392b] transition-colors hover:bg-[#fbe9e7]"
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
    * `:separator_class` - Separator text CSS class (default: "text-[#8a877f]")
    * `:from_input` - Pre-rendered from date input
    * `:to_input` - Pre-rendered to date input
  """
  @impl true
  def date_range_container(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "flex items-center gap-2" end)
      |> assign_new(:separator_class, fn -> "text-[#8a877f]" end)

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
      |> assign(:class, assigns[:class] || nav_link_class(variant))
      |> assign(:icon, assigns[:icon] || nav_link_icon(variant))
      |> assign(:external, external)

    if external do
      ~H"""
      <a href={@navigate} target="_blank" rel="noopener noreferrer" class={@class} title={@label}>
        <.render_icon :if={@icon} name={@icon} class="size-4" />
        <span :if={@label not in [nil, ""]} class="lbl">{@label}</span>
      </a>
      """
    else
      ~H"""
      <.link navigate={@navigate} class={@class} title={@label}>
        <.render_icon :if={@icon} name={@icon} class="size-4" />
        <span :if={@label not in [nil, ""]} class="lbl">{@label}</span>
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
    <thead class="text-xs text-[#3a382f] uppercase bg-[#faf9f6]">
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
      class={[@class, @sortable && "cursor-pointer hover:bg-[#f7f6f3] select-none"]}
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
      |> assign_new(:class, fn -> "border-b border-[#f0efea] bg-white hover:bg-[#f7f6f3]" end)

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
        class="grid size-[30px] place-items-center rounded-[8px] text-[#8a877f] transition-colors hover:text-[#3a382f]"
        phx-click={
          JS.toggle(
            to: "##{@menu_id}",
            in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
            out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
          )
        }
      >
        <.render_icon name={@icon} class="size-4" />
      </button>
      <div
        id={@menu_id}
        class="absolute right-0 z-[60] mt-2 hidden w-[210px] overflow-hidden rounded-[14px] border border-[#ecebe6] bg-white p-1.5 shadow-[0_18px_44px_rgba(30,28,24,0.16)]"
        phx-click-away={
          JS.hide(
            to: "##{@menu_id}",
            transition: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
          )
        }
      >
        <div class="flex flex-col gap-0.5">
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
    * `:class` - CSS class (default: "text-[#a8a5a0]")
  """
  @impl true
  def cell_empty(assigns) do
    assigns =
      assigns
      |> assign_new(:text, fn -> "-" end)
      |> assign_new(:class, fn -> "text-[#a8a5a0]" end)

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
    * `:suffix_class` - CSS class for suffix (default: "text-[#8a877f]")
  """
  @impl true
  def cell_text(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:suffix, fn -> nil end)
      |> assign_new(:suffix_class, fn -> "text-[#8a877f]" end)

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
  Render a list of tags/chips with a `+N` inline expand/collapse toggle.

  Shows `:shown` chips, then a `+N` chip for the `:rest`. Clicking `+N` reveals the rest inline (the
  `+N` swaps to a `- less` collapse handle); clicking it again — or anywhere outside — collapses.
  The toggle is a `Phoenix.LiveView.JS` class swap, so it is never clipped by the table's
  `overflow-x-auto` wrapper.

  ## Assigns
    * `:id` - Stable, unique element id (namespaces the toggle targets)
    * `:shown` - Chips always visible
    * `:rest` - Chips revealed on expand
    * `:more` - Count for the `+N` chip (`0` hides the toggle)
    * `:badge_class` - Chip CSS class
    * `:empty` - Text shown when there are no chips (default `"—"`)
  """
  @tags_default_badge "inline-block max-w-full truncate align-middle rounded-[7px] border border-[#d6e3f5] bg-[#eaf1fb] px-2 py-[3px] font-['Space_Grotesk'] text-[10.5px] font-semibold text-[#3a6cb5]"

  @tags_toggle_class "inline-flex cursor-pointer items-center rounded-[7px] border border-[#e4e2f7] bg-[#f2f1fc] px-[9px] py-[3px] text-[10.5px] font-bold text-[#5b57d6] transition-colors hover:bg-[#e9e7fb]"

  @impl true
  def cell_tags(assigns) do
    assigns =
      assigns
      |> assign_new(:shown, fn -> [] end)
      |> assign_new(:rest, fn -> [] end)
      |> assign_new(:more, fn -> 0 end)
      |> assign_new(:badge_class, fn -> nil end)
      |> assign_new(:empty, fn -> nil end)

    assigns =
      assigns
      |> assign(:badge_class, assigns.badge_class || @tags_default_badge)
      |> assign(:toggle_class, @tags_toggle_class)
      |> assign(:empty, assigns.empty || "—")
      |> assign(:any?, assigns.shown != [] or assigns.rest != [])

    ~H"""
    <div
      :if={@any?}
      id={@id}
      class="flex min-w-0 max-w-full flex-wrap items-center gap-[6px]"
      phx-click-away={@more > 0 && tags_collapse(@id)}
    >
      <span :for={item <- @shown} class={@badge_class}>{item}</span>
      <span id={@id <> "-rest"} class="hidden [&:not(.hidden)]:contents">
        <span :for={item <- @rest} class={@badge_class}>{item}</span>
      </span>
      <button :if={@more > 0} type="button" class={@toggle_class} phx-click={tags_toggle(@id)}>
        <span id={@id <> "-more"}>+{@more}</span>
        <span id={@id <> "-less"} class="hidden">- less</span>
      </button>
    </div>
    <span
      :if={not @any?}
      class="font-['Space_Grotesk'] text-[13px] font-semibold text-[#a8a5a0]"
    >
      {@empty}
    </span>
    """
  end

  defp tags_toggle(id) do
    JS.toggle_class("hidden", to: "##{id}-rest")
    |> JS.toggle_class("hidden", to: "##{id}-more")
    |> JS.toggle_class("hidden", to: "##{id}-less")
  end

  defp tags_collapse(id) do
    JS.add_class("hidden", to: "##{id}-rest")
    |> JS.add_class("hidden", to: "##{id}-less")
    |> JS.remove_class("hidden", to: "##{id}-more")
  end

  @doc """
  Render an overlapping avatar stack with a `+N` inline expand/collapse toggle.

  The people counterpart to `cell_tags/1`, and it behaves identically: `:shown` faces overlap, then a
  `+N` disc stands for the `:rest`. Clicking `+N` reveals the rest in place (the disc swaps to a `−`
  collapse handle); clicking `−`, or anywhere outside, collapses. The toggle is a pure
  `Phoenix.LiveView.JS` class swap, so it survives the table's `overflow-x-auto` wrapper uncut.

  Each entry is a map, so a caller can hand over whatever it has: `:image` draws a photo, and its
  absence falls back to `:initial` on a tinted disc — `:tint` is the caller's, since the tint usually
  belongs to the page's own palette. `:label` becomes the face's `title`.

  ## Assigns
    * `:id` - Stable, unique element id (namespaces the toggle targets)
    * `:shown` - Entries always visible, `%{image:, initial:, label:, tint:}`
    * `:rest` - Entries revealed on expand, same shape
    * `:more` - Count for the `+N` disc (`0` hides the toggle)
    * `:size` - Disc size class (default `"size-[26px]"`)
    * `:empty` - Text shown when there are no entries (default `"—"`)
  """
  @avatars_face "flex-none rounded-full border-2 border-white bg-[#f4f3ef] object-cover"

  @avatars_more "grid flex-none cursor-pointer place-items-center rounded-full border-2 " <>
                  "border-white bg-[#f2f1ec] text-[10px] font-bold text-[#8a877f] transition-colors " <>
                  "hover:bg-[#e9e7e1]"

  @impl true
  def cell_avatars(assigns) do
    assigns =
      assigns
      |> assign_new(:shown, fn -> [] end)
      |> assign_new(:rest, fn -> [] end)
      |> assign_new(:more, fn -> 0 end)
      |> assign_new(:size, fn -> nil end)
      |> assign_new(:empty, fn -> nil end)

    assigns =
      assigns
      |> assign(:size, assigns.size || "size-[26px]")
      |> assign(:empty, assigns.empty || "—")
      |> assign(:face_class, @avatars_face)
      |> assign(:more_class, @avatars_more)
      |> assign(:any?, assigns.shown != [] or assigns.rest != [])

    ~H"""
    <div
      :if={@any?}
      id={@id}
      class="flex min-w-0 max-w-full items-center -space-x-1.5"
      phx-click-away={@more > 0 && tags_collapse(@id)}
    >
      <.avatar_face :for={entry <- @shown} entry={entry} size={@size} face_class={@face_class} />
      <span id={@id <> "-rest"} class="hidden [&:not(.hidden)]:contents">
        <.avatar_face :for={entry <- @rest} entry={entry} size={@size} face_class={@face_class} />
      </span>
      <button
        :if={@more > 0}
        type="button"
        class={[@more_class, @size]}
        phx-click={tags_toggle(@id)}
      >
        <span id={@id <> "-more"}>+{@more}</span>
        <span id={@id <> "-less"} class="hidden">−</span>
      </button>
    </div>
    <span :if={not @any?} class="text-[12px] font-medium text-[#a8a5a0]">{@empty}</span>
    """
  end

  @doc """
  A two-line cell: a primary line over a quieter secondary one.

  The shape almost every admin row leads with — a name over its slug, a site over its date, a person
  over their role. A resource hands over the two strings and this decides how they look.

  `:title` is the row's headline — the thing you scan a column for — and `:meta` is a supporting pair
  that should not compete with it. A leading `:icon` indents the secondary line under the text rather
  than under the icon, so the two lines read as one block.

  ## Assigns
    * `:primary` - the top line
    * `:secondary` - the line beneath it (omitted when nil or "")
    * `:icon` - icon name shown before the primary line
    * `:copy` - `%{id: , value: }` to trail the secondary line with a copy button
    * `:variant` - `:title` (default) or `:meta`
    * `:empty` - text when there is no primary line at all (default `"—"`)
  """
  @stacked_title "truncate text-[13.5px] font-semibold text-[#17161a]"
  @stacked_title_secondary "truncate font-['Space_Grotesk'] text-[11px] font-medium text-[#a8a5a0]"
  @stacked_meta "truncate text-[12.5px] font-medium text-[#3a382f]"
  @stacked_meta_secondary "truncate text-[11px] font-medium text-[#a8a5a0]"

  @impl true
  def cell_stacked(assigns) do
    assigns =
      assigns
      |> assign_new(:secondary, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:copy, fn -> nil end)
      |> assign_new(:variant, fn -> :title end)
      |> assign_new(:empty, fn -> nil end)

    title? = assigns.variant != :meta

    assigns =
      assigns
      |> assign(:empty, assigns.empty || "—")
      |> assign(:primary_class, (title? && @stacked_title) || @stacked_meta)
      |> assign(
        :secondary_class,
        (title? && @stacked_title_secondary) || @stacked_meta_secondary
      )
      |> assign(:blank?, assigns.primary in [nil, ""])
      |> assign(:secondary?, assigns.secondary not in [nil, ""])

    ~H"""
    <div :if={!@blank?} class="min-w-0">
      <div class="flex min-w-0 items-center gap-[7px]">
        <.render_icon :if={@icon} name={@icon} class="size-[14px] shrink-0 text-[#a8a5a0]" />
        <span class={@primary_class} title={@primary}>{@primary}</span>
      </div>

      <div
        :if={@secondary?}
        class={["mt-[2px] flex min-w-0 items-center gap-[5px]", @icon && "pl-[21px]"]}
      >
        <span class={@secondary_class}>{@secondary}</span>
        <.copy_button :if={@copy} id={@copy.id} value={@copy.value} label={@copy[:label]} />
      </div>
    </div>
    <span :if={@blank?} class="text-[12px] font-medium text-[#a8a5a0]">{@empty}</span>
    """
  end

  @doc """
  A wrapping row of icon+count markers, optionally followed by chips.

  What a row's numbers collapse into once they stop deserving a column each — comments, versions,
  contributors, words. The row wraps rather than overflowing, so a narrow column costs a second line
  instead of a scrollbar.

  An item may carry its own `:class` to colour a count that means something (drafts pending review),
  and a chip is for the short labels that ride alongside the numbers, such as a language or a version.

  ## Assigns
    * `:items` - `[%{icon:, value:, label:, class:}]`; `:label` becomes the marker's `title`
    * `:chips` - `[%{text:, class:}]` rendered after the counts
    * `:empty` - text when there is nothing at all (default `"—"`)
  """
  @stats_row "flex flex-wrap items-center gap-x-[11px] gap-y-1.5 text-[11.5px] font-semibold text-[#8a877f]"
  @stats_chip "rounded-[5px] bg-[#f4f3ee] px-[6px] py-[2px] text-[10px] font-bold uppercase tracking-[0.04em] text-[#6d6a63]"

  @impl true
  def cell_stats(assigns) do
    assigns =
      assigns
      |> assign_new(:items, fn -> [] end)
      |> assign_new(:chips, fn -> [] end)
      |> assign_new(:empty, fn -> nil end)

    assigns =
      assigns
      |> assign(:empty, assigns.empty || "—")
      |> assign(:row_class, @stats_row)
      |> assign(:chip_class, @stats_chip)
      |> assign(:any?, assigns.items != [] or assigns.chips != [])

    ~H"""
    <div :if={@any?} class={@row_class}>
      <span
        :for={item <- @items}
        class={["inline-flex items-center gap-[5px]", item[:class]]}
        title={item[:label]}
      >
        <.render_icon
          :if={item[:icon]}
          name={item.icon}
          class={["size-[13px]", item[:class] || "text-[#c3c0b8]"]}
        />
        {item.value}
      </span>

      <span :for={chip <- @chips} class={[@chip_class, chip[:class]]} title={chip[:label]}>
        {chip.text}
      </span>
    </div>
    <span :if={!@any?} class="text-[12px] font-medium text-[#a8a5a0]">{@empty}</span>
    """
  end

  attr :entry, :map, required: true
  attr :size, :string, required: true
  attr :face_class, :string, required: true

  defp avatar_face(assigns) do
    ~H"""
    <img
      :if={@entry[:image]}
      src={@entry[:image]}
      alt={@entry[:label]}
      title={@entry[:label]}
      class={[@face_class, @size, "overflow-hidden text-transparent"]}
    />
    <div
      :if={is_nil(@entry[:image])}
      title={@entry[:label]}
      class={["grid place-items-center", @face_class, @size, @entry[:tint]]}
    >
      <span class="text-[10px] font-bold">{@entry[:initial]}</span>
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
      |> assign_new(:class, fn -> "text-sm text-[#8a877f] hover:text-[#3a382f] underline" end)

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
      |> assign_new(:table_id, fn -> "archive" end)
      |> assign_new(:active_label, fn -> "Active" end)
      |> assign_new(:archived_label, fn -> "Archived" end)

    ~H"""
    <div class="flex rounded-[10px] border border-[#ecebe6] bg-[#f6f5f2] p-[3px]">
      <button
        :for={{label, value} <- [{@active_label, "active"}, {@archived_label, "archived"}]}
        type="button"
        phx-click="archive_filter"
        phx-value-status={value}
        phx-target={@myself}
        class={[
          "cursor-pointer rounded-[8px] px-[15px] py-[7px] text-[12px] font-semibold transition-colors",
          (to_string(@archive_status) == value &&
             "bg-white text-[#17161a] shadow-[0_1px_2px_rgba(30,28,24,0.06)]") ||
            "text-[#8a877f] hover:text-[#3a382f]"
        ]}
      >
        {label}
      </button>
    </div>
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
      |> assign_new(:id, fn -> nil end)
      |> assign_new(:all_selected_label, fn -> "All selected" end)
      |> assign_new(:all_except_label, fn -> "All except %{count} selected" end)
      |> assign_new(:selected_label, fn -> "%{count} selected" end)
      |> assign_new(:clear_label, fn -> "Clear selection" end)
      |> assign_new(:class, fn ->
        "mb-[14px] flex flex-wrap items-center gap-[14px] rounded-[14px] border border-[#d9dcf5] bg-[#eef1fc] px-4 py-3"
      end)

    ~H"""
    <div class={@class}>
      <span class="text-[12.5px] font-bold text-[#3a3f8f]">
        <%= cond do %>
          <% @select_all and @excluded_count == 0 -> %>
            {@all_selected_label}
          <% @select_all and @excluded_count > 0 -> %>
            {String.replace(@all_except_label, "%{count}", to_string(@excluded_count))}
          <% true -> %>
            {String.replace(@selected_label, "%{count}", to_string(@selected_count))}
        <% end %>
      </span>
      <div class="flex flex-wrap items-center gap-2">
        {render_slot(@inner_block)}
      </div>
      <button
        type="button"
        phx-click={clear_selection_js(@myself, @id)}
        class="ml-auto text-[12px] font-semibold text-[#6d6a99] transition-colors hover:text-[#3a3f8f]"
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
    action = assigns.action
    {variant, glyph} = bulk_variant(action)

    assigns =
      assigns
      |> assign(:glyph, glyph)
      |> assign(:hero_icon, action.ui && action.ui.icon)
      |> assign(:label, (action.ui && action.ui.label) || Phoenix.Naming.humanize(action.name))
      |> assign(:btn_class, (action.ui && action.ui.class) || bulk_button_class(variant))

    ~H"""
    <button
      type="button"
      phx-click="bulk_action"
      phx-value-action={@action.name}
      phx-target={@myself}
      class={@btn_class}
      data-confirm={@action.confirm}
    >
      <.bulk_glyph :if={@glyph} glyph={@glyph} />
      <.render_icon :if={is_nil(@glyph) and @hero_icon} name={@hero_icon} class="size-[14px]" />
      {@label}
    </button>
    """
  end

  @bulk_btn_base "inline-flex h-[34px] items-center gap-1.5 rounded-[9px] border px-[13px] text-[12px] font-semibold transition-colors [&_svg]:size-[14px]"

  defp bulk_variant(action) do
    case bulk_kind(action) do
      :destroy -> {:neutral, :archive}
      :unarchive -> {:success, :unarchive}
      :permanent_destroy -> {:danger, :trash}
      :activate -> {:success, :check}
      _ -> {:primary, nil}
    end
  end

  @bulk_kinds [:destroy, :unarchive, :permanent_destroy, :activate]
  defp bulk_kind(%{type: t}) when t in @bulk_kinds, do: t
  defp bulk_kind(%{handler: {_scope, kind}}) when kind in @bulk_kinds, do: kind
  defp bulk_kind(%{handler: h}) when h in @bulk_kinds, do: h
  defp bulk_kind(%{name: :archive}), do: :destroy
  defp bulk_kind(%{name: n}) when n in @bulk_kinds, do: n
  defp bulk_kind(_action), do: nil

  defp bulk_button_class(:success),
    do: @bulk_btn_base <> " border-[#cfe6d8] bg-white text-[#177a53] hover:bg-[#eefaf2]"

  defp bulk_button_class(:primary),
    do: @bulk_btn_base <> " border-[#dcdbf5] bg-white text-[#4f4bcc] hover:bg-[#f2f1fc]"

  defp bulk_button_class(:danger),
    do: @bulk_btn_base <> " border-[#f0dcd8] bg-[#fdf3f1] text-[#c0473d] hover:bg-[#fbe9e7]"

  defp bulk_button_class(_neutral),
    do: @bulk_btn_base <> " border-[#e6e4de] bg-white text-[#5c5a54] hover:bg-[#f7f6f3]"

  attr :glyph, :atom, required: true

  defp bulk_glyph(%{glyph: :archive} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.9"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <rect x="3" y="4" width="18" height="4" rx="1" />
      <path d="M5 8v11a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8" />
      <path d="M10 12h4" />
    </svg>
    """
  end

  defp bulk_glyph(%{glyph: :unarchive} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.9"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <rect x="3" y="4" width="18" height="4" rx="1" />
      <path d="M5 8v11a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8" />
      <path d="M12 18v-6M9.5 14.5 12 12l2.5 2.5" />
    </svg>
    """
  end

  defp bulk_glyph(%{glyph: :trash} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.9"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13" />
    </svg>
    """
  end

  defp bulk_glyph(%{glyph: :check} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M20 6 9 17l-5-5" />
    </svg>
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
  @pagination_nav "h-9 rounded-[9px] border border-[#ecebe6] bg-white px-3.5 text-[12px] " <>
                    "font-semibold text-[#6d6a63] transition-colors hover:bg-[#f7f6f3] " <>
                    "disabled:cursor-default disabled:bg-[#f6f5f2] disabled:text-[#c3c0b8]"

  @pagination_page "h-9 min-w-9 rounded-[9px] border px-2.5 text-[12px] font-bold transition-colors"

  @impl true
  def pagination_container(assigns) do
    assigns =
      assigns
      |> assign_new(:show_total, fn -> true end)
      |> assign_new(:page_info_format, fn -> "Page {page} of {total}" end)

    ~H"""
    <div class="mt-5 flex flex-wrap items-center justify-center gap-2">
      {render_slot(@inner_block)}
    </div>
    <div :if={@show_total} class="mt-2 text-center text-[12px] font-semibold text-[#a8a5a0]">
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
      |> assign_new(:class, fn -> @pagination_nav end)

    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-value-page={@page}
      phx-target={@myself}
      disabled={@disabled}
      class={@class}
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

    assigns =
      assigns
      |> assign(:is_active, assigns.page_num == assigns.current_page)
      |> assign(:page_class, @pagination_page)

    ~H"""
    <button
      type="button"
      phx-click="go_to_page"
      phx-value-page={@page_num}
      phx-target={@myself}
      disabled={@disabled}
      class={[
        @page_class,
        (@is_active && "border-[#dcdbf5] bg-[#f2f1fc] text-[#4f4bcc]") ||
          "border-[#ecebe6] bg-white text-[#6d6a63] hover:bg-[#f7f6f3]"
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
  The list/grid switch — one recessed tray with the active view lifted onto a white tile. The single
  switcher every admin page (and every `fallback: __MODULE__` adapter) uses.

  The buttons are inlined here rather than drawn as a child component, and each glyph goes through
  `switcher_icon_class/1` so its name reaches the CSS compiler as a literal.

  ## Assigns
    * `:switchable_templates` - List of template modules
    * `:current_template` - Currently active template module
    * `:myself` - LiveComponent target
  """
  @impl true
  def template_switcher(assigns) do
    ~H"""
    <div
      :if={length(@switchable_templates) > 1}
      class="flex flex-none rounded-[11px] border border-[#ecebe6] bg-[#efeee9] p-[3px]"
    >
      <button
        :for={template <- @switchable_templates}
        type="button"
        phx-click="switch_template"
        phx-value-template={template.name()}
        phx-target={@myself}
        title={template.label()}
        aria-pressed={to_string(@current_template.name() == template.name())}
        class={[
          "grid size-[34px] place-items-center rounded-[9px] transition-colors",
          (@current_template.name() == template.name() &&
             "bg-white text-[#4f4bcc] shadow-[0_1px_2px_rgba(30,28,24,0.06)]") ||
            "text-[#8a877f] hover:text-[#3a382f]"
        ]}
      >
        <span class={switcher_icon_class(template.icon())} />
      </button>
    </div>
    """
  end

  @doc """
  The class that draws a switcher button's glyph, written literally per icon name so the runtime CSS
  compiler emits its mask. Falls back to the raw name for any icon not named here (which the compiler
  only sees if it appears literally elsewhere in the source).
  """
  @spec switcher_icon_class(String.t()) :: String.t()
  def switcher_icon_class("hero-squares-2x2"), do: "hero-squares-2x2 size-4"
  def switcher_icon_class("hero-table-cells"), do: "hero-table-cells size-4"
  def switcher_icon_class("hero-queue-list"), do: "hero-queue-list size-4"
  def switcher_icon_class("hero-bars-3"), do: "hero-bars-3 size-4"
  def switcher_icon_class("hero-photo"), do: "hero-photo size-4"
  def switcher_icon_class("hero-document-text"), do: "hero-document-text size-4"
  def switcher_icon_class(name), do: "#{name} size-4"

  @doc """
  A single switcher button, for the behaviour's `template_switcher_button` callback.
  `template_switcher/1` inlines its own buttons rather than calling this.
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
        "grid size-[34px] place-items-center rounded-[9px] transition-colors",
        (@is_active && "bg-white text-[#4f4bcc] shadow-[0_1px_2px_rgba(30,28,24,0.06)]") ||
          "text-[#8a877f] hover:text-[#3a382f]"
      ]}
      title={@template.label()}
      aria-pressed={to_string(@is_active)}
    >
      <span class={switcher_icon_class(@template.icon())} />
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

  @doc """
  Render a field wrapper with label, input, error display and help text.

  ## Assigns
    * `:label` - label text above the input
    * `:required` - whether to mark the label required
    * `:field_name` - the input's id, used as the label's `for`
    * `:errors` - error messages, rendered below the input
    * `:description` - help text, rendered below the errors
    * `:class` - extra wrapper classes
  """
  @impl true
  def field_wrapper(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:field_name, fn -> nil end)
      |> assign_new(:required, fn -> false end)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:class, fn -> "flex flex-col gap-[7px]" end)

    has_errors = assigns.errors != []
    assigns = assign(assigns, :has_errors, has_errors)

    ~H"""
    <div class={@class}>
      <label :if={@label} class="block text-[10.5px] font-bold text-[#8a877f]" for={@field_name}>
        {@label}
        <span :if={@required} class="ml-0.5 text-[#e5484d]">*</span>
      </label>
      <div class={[@has_errors && "rounded-[11px] ring-1 ring-[#f0dcd8]"]}>
        {render_slot(@inner_block)}
      </div>
      <.field_error :if={@has_errors} errors={@errors} />
      <p
        :if={@description}
        data-role="gervaz-field-description"
        class="text-[11.5px] font-medium leading-[1.5] text-[#8a877f]"
      >
        {@description}
      </p>
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
      |> assign_new(:class, fn -> "rounded-[16px] border border-[#ecebe6] p-5" end)

    ~H"""
    <fieldset class={@class}>
      <%= if @collapsible do %>
        <legend class="px-2">
          <details open={!@collapsed}>
            <summary class="cursor-pointer select-none text-[13px] font-bold text-[#17161a]">
              {@label}
            </summary>
            <p :if={@description} class="mt-1 text-[12px] font-medium text-[#8a877f]">
              {@description}
            </p>
            <div class="mt-4 space-y-4">
              {render_slot(@inner_block)}
            </div>
          </details>
        </legend>
      <% else %>
        <legend :if={@label} class="px-2 text-[13px] font-bold text-[#17161a]">
          {@label}
        </legend>
        <p :if={@description} class="mt-1 text-[12px] font-medium text-[#8a877f]">
          {@description}
        </p>
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
            <div
              :if={index > 0}
              class={[
                "w-8 h-0.5 mx-1",
                step_connector_class(step.status)
              ]}
            />
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
        "flex items-center justify-between border-t border-[#ecebe6] pt-6"
      end)

    ~H"""
    <div class={@class}>
      <button
        :if={@can_go_back}
        type="button"
        phx-click="prev_step"
        phx-target={@phx_target}
        class={secondary_button_class()}
      >
        <.render_icon name="hero-arrow-left" class="size-4" />
        {@prev_label}
      </button>
      <div :if={!@can_go_back} />

      <%= if @is_last_step do %>
        <button type="submit" class={primary_button_class(true)}>
          {@submit_label}
          <.render_icon name="hero-check" class="size-4" />
        </button>
      <% else %>
        <button
          type="button"
          phx-click="next_step"
          phx-target={@phx_target}
          disabled={!@can_advance}
          class={primary_button_class(@can_advance)}
        >
          {@next_label}
          <.render_icon name="hero-arrow-right" class="size-4" />
        </button>
      <% end %>
    </div>
    """
  end

  @doc """
  The form's primary button — the same gradient the submit row wears.

  Call it from a template drawing its own navigation, so its primary button matches the submit row.
  """
  @spec primary_button_class(boolean()) :: list()
  def primary_button_class(enabled?) do
    [
      "inline-flex h-[42px] items-center gap-2 rounded-[11px] px-[18px] text-[12.5px] font-bold",
      "text-white transition-opacity",
      if(enabled?,
        do:
          "bg-[linear-gradient(140deg,#6d69e6,#4f4bcc)] shadow-[0_5px_14px_rgba(79,75,204,0.28)] hover:opacity-95",
        else: "cursor-not-allowed bg-[#c3c0b8]"
      )
    ]
  end

  @doc """
  The bordered companion to `primary_button_class/1` — Back, Cancel, and anything else that sits
  beside the primary action without competing with it.
  """
  @spec secondary_button_class() :: String.t()
  def secondary_button_class do
    "inline-flex h-[42px] items-center gap-[7px] rounded-[11px] border border-[#ecebe6] " <>
      "bg-white px-[15px] text-[12.5px] font-semibold text-[#5c5a54] transition-colors " <>
      "hover:bg-[#f7f6f3]"
  end

  @impl true
  def upload_dropzone(assigns) do
    assigns =
      assigns
      |> assign_new(:accept, fn -> nil end)
      |> assign_new(:max_entries, fn -> 1 end)
      |> assign_new(:class, fn ->
        "flex w-full cursor-pointer flex-col items-center justify-center rounded-[14px] border-[1.5px] border-dashed border-[#d9d7d0] bg-[#faf9f6] px-4 py-[34px] text-center transition-colors hover:border-[#5b57d6] hover:bg-[#f7f6fd]"
      end)

    ~H"""
    <label class={@class} phx-drop-target={@upload_ref}>
      <span class="mb-3 grid size-[50px] place-items-center rounded-[14px] bg-[#f2f1fc] text-[#5b57d6]">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.8"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="size-6"
        >
          <path d="M12 16V4M8 8l4-4 4 4" />
          <path d="M4 16v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2" />
        </svg>
      </span>
      <p class="text-[13.5px] font-semibold text-[#3a382f]">
        <span class="text-[#4f4bcc]">Click to upload</span> or drag and drop
      </p>
      <p :if={@accept} class="mt-[5px] text-[11px] font-medium text-[#a8a5a0]">
        {format_accept(@accept)}
      </p>
      <p :if={@max_entries > 1} class="mt-1 text-[11px] font-medium text-[#a8a5a0]">
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
      |> assign_new(:class, fn ->
        "flex items-center gap-3 rounded-[12px] border border-[#ecebe6] bg-white p-[10px]"
      end)

    ~H"""
    <div class={@class}>
      <.render_icon name="hero-document" class="size-8 shrink-0 text-[#8a877f]" />
      <div class="min-w-0 flex-1">
        <p class="truncate text-[12.5px] font-semibold text-[#1b1a18]">{@entry.client_name}</p>
        <p class="font-['Space_Grotesk'] text-[11px] font-medium text-[#8a877f]">
          {format_filesize(@entry.client_size)}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Upload progress bar: the entry's filename, its percentage, and a track filled to that percentage.

  ## Assigns
    * `:entry` - a `Phoenix.LiveView.UploadEntry`
    * `:class` - wrapper classes (default `"w-full"`)

  The fill width rides an inline `style`, not a Tailwind class, as in `cell_bars/1`: the percentage
  arrives from LiveView's upload state as the bytes land, so there is no literal for Tailwind to
  find.
  """
  @impl true
  def upload_progress(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "w-full" end)

    ~H"""
    <div class={@class}>
      <div class="mb-1 flex items-center justify-between">
        <span class="truncate text-[11.5px] font-semibold text-[#3a382f]">
          {@entry.client_name}
        </span>
        <span class="font-['Space_Grotesk'] text-[10.5px] font-semibold text-[#8a877f]">
          {@entry.progress}%
        </span>
      </div>
      <div class="h-[5px] w-full overflow-hidden rounded-full bg-[#efeee9]">
        <div
          class="h-full rounded-full bg-[#5b57d6] transition-all duration-300 ease-out"
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
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:id, fn -> nil end)

    ~H"""
    <label class={[
      "inline-flex cursor-pointer items-center",
      @disabled && "opacity-50 cursor-not-allowed"
    ]}>
      <input type="hidden" name={@name} value="false" />
      <div class="relative w-11 h-6">
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          disabled={@disabled}
          class="sr-only"
          role="switch"
          aria-checked={to_string(@checked)}
        />
        <div class={[
          "h-6 w-11 rounded-full transition-colors duration-200 ease-in-out",
          if(@checked, do: "bg-[#5b57d6]", else: "bg-[#dcdad2]")
        ]} />
        <div class={[
          "absolute left-0.5 top-0.5 size-5 rounded-full bg-white shadow-[0_1px_2px_rgba(30,28,24,0.12)] transition-transform duration-200 ease-in-out",
          if(@checked, do: "translate-x-5", else: "translate-x-0")
        ]} />
      </div>
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
        "h-2 w-full cursor-pointer appearance-none rounded-full bg-[#efeee9] accent-[#5b57d6]"
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
        class="text-sm font-medium text-[#3a382f] tabular-nums min-w-[3ch] text-right"
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
      |> assign_new(:class, fn -> multiline_class("") end)
      |> assign_new(:rows, fn -> 4 end)
      |> assign_new(:phx_debounce, fn ->
        case Map.fetch(assigns, :"phx-debounce") do
          {:ok, value} -> value
          :error -> 300
        end
      end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:readonly, fn -> false end)

    ~H"""
    <textarea
      name={@name}
      placeholder={@placeholder}
      rows={@rows}
      disabled={@disabled}
      readonly={@readonly}
      class={[@class, (@disabled || @readonly) && disabled_class()]}
      phx-debounce={@phx_debounce}
    >{@value}</textarea>
    """
  end

  @impl true
  def json_editor(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> multiline_class("font-mono ") end)
      |> assign_new(:rows, fn -> 8 end)
      |> assign_new(:disabled, fn -> false end)

    ~H"""
    <textarea
      name={@name}
      rows={@rows}
      disabled={@disabled}
      class={[@class, @disabled && disabled_class()]}
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
        <h4 class="text-sm font-semibold text-[#17161a]">{@label}</h4>
      </div>
      <div class="space-y-3">
        {render_slot(@inner_block)}
      </div>
      <button
        type="button"
        phx-click="add_nested"
        phx-target={@phx_target}
        phx-value-path={@field_path}
        class="inline-flex h-9 items-center gap-[7px] rounded-[10px] border border-[#dcdbf5] bg-[#f2f1fc] px-[13px] text-[12px] font-semibold text-[#4f4bcc] transition-colors hover:bg-[#e9e7fb]"
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
        <h4 class="text-sm font-semibold text-[#17161a]">{@label}</h4>
      </div>
      <div class="space-y-2">
        {render_slot(@inner_block)}
      </div>
      <button
        type="button"
        phx-click="add_array_item"
        phx-target={@phx_target}
        phx-value-path={@field_path}
        class="inline-flex h-9 items-center gap-[7px] rounded-[10px] border border-[#dcdbf5] bg-[#f2f1fc] px-[13px] text-[12px] font-semibold text-[#4f4bcc] transition-colors hover:bg-[#e9e7fb]"
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
      |> assign_new(:table_id, fn -> nil end)
      |> assign_new(:class, fn -> "space-y-2" end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:input_class, fn -> "flex-1 " <> input_class(false) end)
      |> assign(:items_with_index, Enum.with_index(assigns[:items] || []))

    ~H"""
    <div id={"string-list-#{@table_id}-#{@field_name}"} class={@class}>
      <input type="hidden" name={"form[#{@field_name}][]"} value="" />

      <%= for {item, idx} <- @items_with_index do %>
        <div class="flex items-center gap-2" id={"string-list-#{@table_id}-#{@field_name}-#{idx}"}>
          <input
            type="text"
            name={"form[#{@field_name}][]"}
            value={item}
            placeholder={@placeholder}
            disabled={@disabled}
            class={[@input_class, @disabled && disabled_class()]}
          />
          <button
            :if={!@disabled}
            type="button"
            phx-click="remove_list_item"
            phx-value-field={@field_name}
            phx-value-index={idx}
            phx-target={@target}
            class="inline-flex items-center rounded-[8px] p-1.5 text-[#a8a5a0] transition-colors hover:bg-[#fdf4f3] hover:text-[#c0392b]"
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
        class="inline-flex h-9 items-center gap-[7px] rounded-[10px] border border-[#dcdbf5] bg-[#f2f1fc] px-[13px] text-[12px] font-semibold text-[#4f4bcc] transition-colors hover:bg-[#e9e7fb]"
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
        "h-[42px] w-full rounded-[11px] border border-[#ecebe6] bg-white px-[13px] text-[12.5px] font-medium text-[#3a382f] outline-none transition-shadow focus:border-[#c3c1f0] focus:shadow-[0_0_0_3px_rgba(91,87,214,0.1)] w-full"
      end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:phx_debounce, fn ->
        case Map.fetch(assigns, :"phx-debounce") do
          {:ok, value} -> value
          :error -> 300
        end
      end)
      |> assign_new(:field_name, fn -> nil end)
      |> assign_new(:target, fn -> nil end)
      |> assign_new(:table_id, fn -> nil end)
      |> assign(
        :dropdown_id,
        "combobox-dropdown-#{assigns[:table_id]}-#{assigns[:field_name] || assigns[:name]}"
      )

    ~H"""
    <div class="relative" phx-click-away={JS.hide(to: "##{@dropdown_id}")}>
      <.render_icon
        :if={@icon}
        name={@icon}
        class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#a8a5a0]"
      />
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        disabled={@disabled}
        class={[@class, @icon && "pl-9", @disabled && disabled_class()]}
        phx-debounce={@phx_debounce}
        phx-click={JS.show(to: "##{@dropdown_id}")}
        phx-focus={JS.show(to: "##{@dropdown_id}")}
        phx-keyup={JS.show(to: "##{@dropdown_id}")}
        autocomplete="off"
      />
      <div
        id={@dropdown_id}
        class="absolute z-50 mt-1 hidden max-h-60 w-full overflow-auto rounded-[11px] border border-[#ecebe6] bg-white shadow-[0_10px_30px_rgba(23,22,26,0.08)]"
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
            class="block w-full px-3 py-2 text-left text-[12.5px] font-medium text-[#3a382f] transition-colors hover:bg-[#f2f1fc] hover:text-[#4f4bcc]"
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
      <p
        :for={error <- @errors}
        class="flex items-center gap-1 text-[11.5px] font-medium text-[#c0392b]"
      >
        <.render_icon name="hero-exclamation-circle" class="size-4 shrink-0" />
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
        "block w-full text-[12.5px] font-medium text-[#8a877f] " <>
          "file:mr-4 file:rounded-[10px] file:border file:border-[#dcdbf5] file:bg-[#f2f1fc] " <>
          "file:px-[13px] file:py-[9px] file:text-[12px] file:font-semibold file:text-[#4f4bcc] " <>
          "hover:file:bg-[#e9e7fb]"
      end)

    ~H"""
    <div class="space-y-2">
      <div class={@class}>
        {render_slot(@inner_block)}
      </div>
      <p :if={@accept} class="text-[11px] font-medium text-[#a8a5a0]">
        Accepted: {format_accept(@accept)}
      </p>
      <p :if={@max_entries > 1} class="text-[11px] font-medium text-[#a8a5a0]">
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
        "group flex items-center gap-3 rounded-[12px] border border-[#ecebe6] bg-[#faf9f6] p-3"
      end)
      |> assign_new(:filename, fn -> file[:filename] || file[:name] || "File" end)
      |> assign_new(:url, fn -> file[:url] end)
      |> assign_new(:size, fn -> file[:size] end)
      |> assign_new(:format, fn -> file[:format] end)
      |> assign_new(:is_image, fn -> image_file?(file) end)
      |> assign_new(:phx_target, fn -> nil end)

    ~H"""
    <div class={@class}>
      <div class="size-14 flex-shrink-0 overflow-hidden rounded-[10px] bg-[#f0efea]">
        <%= if @is_image && @url do %>
          <img src={@url} alt={@filename} class="size-full object-cover" />
        <% else %>
          <div class="grid size-full place-items-center">
            <.render_icon name={file_type_icon(@format)} class="size-7 text-[#c3c0b8]" />
          </div>
        <% end %>
      </div>
      <div class="min-w-0 flex-1">
        <p class="truncate text-[13px] font-semibold text-[#17161a]">{@filename}</p>
        <p :if={@size || @format} class="text-[11px] font-medium text-[#a8a5a0]">
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
        class="flex-shrink-0 rounded-[8px] p-1.5 text-[#a8a5a0] opacity-0 transition-colors hover:bg-[#fdf4f3] hover:text-[#c0392b] group-hover:opacity-100"
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
    base = "grid size-4 place-items-center rounded-[5px] border transition-colors"

    if selected?(value, selected_set) do
      "#{base} border-[#5b57d6] bg-[#5b57d6] text-white"
    else
      "#{base} border-[#dcdad2] bg-white"
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

  @row_action_btn "grid size-[30px] place-items-center rounded-[8px] border border-[#ecebe6] bg-[#faf9f6] text-[#5c5a54] transition-colors hover:bg-[#f2f1fc] hover:text-[#4f4bcc] [&>span:not(.lbl)]:size-[15px]! [&_.lbl]:hidden"

  @row_action_danger "grid size-[30px] place-items-center rounded-[8px] border border-[#f0dcd8] bg-[#fdf3f1] text-[#c0473d] transition-colors hover:bg-[#fbe9e7] [&>span:not(.lbl)]:size-[15px]! [&_.lbl]:hidden"

  @row_action_success "grid size-[30px] place-items-center rounded-[8px] border border-[#cfe8dd] bg-[#eaf6ee] text-[#177a53] transition-colors hover:bg-[#dcefe4] [&>span:not(.lbl)]:size-[15px]! [&_.lbl]:hidden"

  defp button_class(:primary),
    do:
      "inline-flex h-[38px] items-center gap-2 rounded-xl bg-[linear-gradient(140deg,#6d69e6,#4f4bcc)] px-[15px] text-[12.5px] font-bold text-white shadow-[0_5px_14px_rgba(79,75,204,0.28)] transition-opacity hover:opacity-95"

  defp button_class(:danger), do: @row_action_danger
  defp button_class(:destroy), do: @row_action_danger
  defp button_class(:permanent_destroy), do: @row_action_danger
  defp button_class(:unarchive), do: @row_action_success

  defp button_class(:secondary),
    do:
      "inline-flex h-[38px] items-center gap-1.5 rounded-[10px] border border-[#ecebe6] bg-white px-[13px] text-[12px] font-semibold text-[#5c5a54] transition-colors hover:bg-[#f7f6f3]"

  defp button_class(_), do: @row_action_btn

  defp button_icon(_variant), do: nil

  defp nav_link_class(:edit), do: @row_action_btn
  defp nav_link_class(:show), do: @row_action_btn
  defp nav_link_class(:external), do: @row_action_btn
  defp nav_link_class(_), do: @row_action_btn

  defp nav_link_icon(:edit), do: "hero-pencil"
  defp nav_link_icon(:show), do: "hero-eye"
  defp nav_link_icon(_), do: nil

  defp icon_name(:boolean_true), do: "hero-check"
  defp icon_name(:boolean_false), do: "hero-x-mark"
  defp icon_name(_), do: nil

  defp icon_class(:boolean_true), do: "size-5 text-[#177a53]"
  defp icon_class(:boolean_false), do: "size-5 text-[#c0473d]"
  defp icon_class(_), do: "size-5"

  defp cell_datetime_class(:relative), do: "text-[#5c5a54]"
  defp cell_datetime_class(_), do: nil

  defp clear_selection_js(myself, scope) do
    JS.push("clear_selection", target: myself)
    |> Shared.uncheck_all(scope)
  end

  defp format_page_info(format, page, total_pages, total_count) do
    format
    |> String.replace("{page}", to_string(page))
    |> String.replace("{total}", to_string(total_pages || "?"))
    |> String.replace("{count}", to_string(total_count || ""))
  end

  defp step_circle_class(:complete, _current),
    do: "border-[#5b57d6] bg-[#5b57d6] text-white"

  defp step_circle_class(_status, true),
    do: "border-[#5b57d6] bg-white text-[#4f4bcc]"

  defp step_circle_class(:error, _current),
    do: "border-[#e5484d] bg-white text-[#c0392b]"

  defp step_circle_class(_status, false),
    do: "border-[#e0ded7] bg-white text-[#a8a5a0]"

  defp step_connector_class(:complete), do: "bg-[#5b57d6]"
  defp step_connector_class(_), do: "bg-[#e0ded7]"

  defp step_label_class(:complete, _current), do: "font-semibold text-[#4f4bcc]"
  defp step_label_class(_status, true), do: "font-semibold text-[#4f4bcc]"
  defp step_label_class(:error, _current), do: "font-semibold text-[#c0392b]"
  defp step_label_class(_, _), do: "font-medium text-[#8a877f]"

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
      <div class="inline-block size-8 animate-spin rounded-full border-4 border-[#dcdbf5] border-t-[#5b57d6]">
      </div>
      <p :if={@text} class="mt-2 text-[#8a877f]">{@text}</p>
      <p :if={!@text} class="mt-2 text-[#8a877f]">Loading...</p>
    </div>
    """
  end

  defp render_skeleton_loading(assigns) do
    ~H"""
    <div class={["space-y-3 p-4", @class]}>
      <div class="animate-pulse space-y-4">
        <div class="flex items-center space-x-4">
          <div class="rounded-full bg-[#efeee9] h-10 w-10"></div>
          <div class="flex-1 space-y-2">
            <div class="h-4 bg-[#efeee9] rounded w-3/4"></div>
            <div class="h-4 bg-[#efeee9] rounded w-1/2"></div>
          </div>
        </div>
        <div class="h-4 bg-[#efeee9] rounded"></div>
        <div class="h-4 bg-[#efeee9] rounded w-5/6"></div>
        <div class="h-4 bg-[#efeee9] rounded w-4/6"></div>
        <div class="flex items-center space-x-4 pt-2">
          <div class="rounded-full bg-[#efeee9] h-10 w-10"></div>
          <div class="flex-1 space-y-2">
            <div class="h-4 bg-[#efeee9] rounded w-2/3"></div>
            <div class="h-4 bg-[#efeee9] rounded w-1/3"></div>
          </div>
        </div>
        <div class="h-4 bg-[#efeee9] rounded w-full"></div>
        <div class="h-4 bg-[#efeee9] rounded w-3/4"></div>
      </div>
    </div>
    """
  end

  defp render_dots_loading(assigns) do
    ~H"""
    <div class={["py-12 text-center", @class]}>
      <div class="flex justify-center space-x-2">
        <div class="size-3 animate-bounce rounded-full bg-[#5b57d6] [animation-delay:-0.3s]"></div>
        <div class="size-3 animate-bounce rounded-full bg-[#5b57d6] [animation-delay:-0.15s]"></div>
        <div class="size-3 animate-bounce rounded-full bg-[#5b57d6]"></div>
      </div>
      <p :if={@text} class="mt-4 text-[#8a877f]">{@text}</p>
      <p :if={!@text} class="mt-4 text-[#8a877f]">Loading...</p>
    </div>
    """
  end

  @doc """
  Render a static alert/notice.

  ## Assigns
    * `:type` - `:info` | `:warning` | `:error` | `:success` | `:neutral`
    * `:title` - optional headline string
    * `:content` - body string or pre-rendered inner block
    * `:icon` - optional heroicon name
    * `:dismissible` - boolean
    * `:dismiss_event` - phx-click event name for the dismiss button
    * `:dismiss_value` - phx-value-name payload for dismiss
    * `:phx_target` - LiveComponent target
    * `:class` - extra wrapper classes
    * `:inner_block` - optional slot for HEEx content (overrides `:content`)
  """
  @impl true
  def alert(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> :info end)
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:content, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:dismissible, fn -> false end)
      |> assign_new(:dismiss_event, fn -> "dismiss_notice" end)
      |> assign_new(:dismiss_value, fn -> nil end)
      |> assign_new(:phx_target, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign(:tone, alert_tone(Map.get(assigns, :type, :info)))

    ~H"""
    <div
      class={[
        "flex items-start gap-3 rounded-[12px] border p-4",
        @tone.wrapper,
        @class
      ]}
      role="alert"
    >
      <.render_icon
        :if={@icon}
        name={@icon}
        class={["w-5 h-5 mt-0.5 shrink-0", @tone.icon]}
      />
      <div class="flex-1 min-w-0">
        <h3 :if={@title} class={["text-sm font-semibold", @tone.title]}>
          {@title}
        </h3>
        <div
          :if={@content && !@inner_block}
          class={["text-sm", @tone.body, if(@title, do: "mt-1", else: "")]}
        >
          {@content}
        </div>
        <div :if={@inner_block} class={["text-sm", @tone.body, if(@title, do: "mt-1", else: "")]}>
          {render_slot(@inner_block)}
        </div>
      </div>
      <button
        :if={@dismissible}
        type="button"
        phx-click={@dismiss_event}
        phx-value-name={@dismiss_value}
        phx-target={@phx_target}
        class={["shrink-0 rounded p-1 hover:bg-black/5 transition-colors", @tone.icon]}
        aria-label="Dismiss"
      >
        <span class="hero-x-mark w-4 h-4"></span>
      </button>
    </div>
    """
  end

  defp alert_tone(:info),
    do: %{
      wrapper: "border-[#dcdbf5] bg-[#f2f1fc]",
      icon: "text-[#5b57d6]",
      title: "text-[#3a3f8f]",
      body: "text-[#4f4bcc]"
    }

  defp alert_tone(:warning),
    do: %{
      wrapper: "border-[#f0e2c4] bg-[#fbf1df]",
      icon: "text-[#a5691a]",
      title: "text-[#7a4d13]",
      body: "text-[#a5691a]"
    }

  defp alert_tone(:error),
    do: %{
      wrapper: "border-[#f0dcd8] bg-[#fdf3f1]",
      icon: "text-[#c0392b]",
      title: "text-[#8f2c21]",
      body: "text-[#c0473d]"
    }

  defp alert_tone(:success),
    do: %{
      wrapper: "border-[#cfe8da] bg-[#eaf6ee]",
      icon: "text-[#177a53]",
      title: "text-[#11593c]",
      body: "text-[#177a53]"
    }

  defp alert_tone(_),
    do: %{
      wrapper: "border-[#ecebe6] bg-[#faf9f6]",
      icon: "text-[#a8a5a0]",
      title: "text-[#17161a]",
      body: "text-[#6d6a63]"
    }

  @doc """
  Render the form header (title + description).

  ## Assigns
    * `:title` - heading text
    * `:description` - subtitle text
    * `:icon` - optional heroicon name
    * `:class` - extra wrapper classes
  """
  @impl true
  def form_header(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:class, fn -> nil end)

    ~H"""
    <div class={["mb-6 flex items-start gap-3", @class]}>
      <.render_icon :if={@icon} name={@icon} class="mt-1 size-[18px] shrink-0 text-[#a8a5a0]" />
      <div class="min-w-0 flex-1">
        <h2 :if={@title} class="text-[15px] font-bold tracking-[-0.01em] text-[#17161a]">
          {@title}
        </h2>
        <p :if={@description} class="mt-[5px] text-[12.5px] font-medium text-[#8a877f]">
          {@description}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Render the form footer (content below the submit row).

  ## Assigns
    * `:content` - footer text
    * `:class` - extra wrapper classes
    * `:inner_block` - optional slot
  """
  @impl true
  def form_footer(assigns) do
    assigns =
      assigns
      |> assign_new(:content, fn -> nil end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:inner_block, fn -> nil end)

    ~H"""
    <div class={["mt-4 text-[12px] font-medium text-[#8a877f]", @class]}>
      <div :if={@content && !@inner_block}>{@content}</div>
      <div :if={@inner_block}>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  defp render_icon(assigns) do
    name = assigns[:name] || ""

    assigns = %{
      icon: String.starts_with?(name, "hero-") && name,
      class: assigns[:class] || "w-5 h-5"
    }

    ~H"""
    <span class={[@icon, @class]}></span>
    """
  end
end

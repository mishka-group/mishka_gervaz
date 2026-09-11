defmodule MishkaGervaz.Table.Templates.MediaGallery do
  @moduledoc """
  Media gallery template for image/file-heavy data.

  Optimized for displaying images, videos, and files with:
  - Thumbnail grid with hover preview
  - Lightbox for full-size viewing
  - File type icons for non-image files
  - Quick actions overlay

  ## Features
  - `:filter` - Filter by file type, date, etc.
  - `:select` - Multi-select for bulk operations
  - `:bulk_actions` - Bulk download, delete, move
  - `:paginate` - Infinite scroll preferred
  - `:expand` - Lightbox expansion

  ## Column-Based Layout

  MediaGallery uses the columns DSL to determine what to display:
  - First visible column becomes the thumbnail image
  - Remaining visible columns are rendered below the thumbnail in order

  Use `visible fn state -> state.template.name() == :media_gallery end` to show columns
  only in MediaGallery, or `visible fn state -> state.template.name() == :table end`
  for Table-only columns.

  ## The card's actions

  A card is small, so its actions are not equals. One is the star over the thumbnail — a toggle you
  read as state, not as a button. One is wide and labelled, because a card needs a control you can
  hit without decoding a glyph. The rest are bordered squares beside it, red if they destroy
  something. `split_actions/3` decides which is which, and `:overlay_action` / `:primary_action`
  below let a resource whose actions are named differently say so.

  ## The thumbnail that fails to load

  A card paints its type glyph behind the thumbnail, so a file whose bytes have gone only has to hide
  the broken `<img>` for the glyph to be what you see; a thumbnail that does arrive is put on white,
  or a transparent PNG picks up the tile's tint. Both need to know how the image ended, which is a
  question only the browser can answer.

  This requires the consuming app to register a `MediaThumb` JS hook in its ADMIN bundle. It reads
  `data-loaded-background` from the hook element for the colour a loaded image sits on, and binds
  `load`/`error` on the `<img>` inside it. The `onload=`/`onerror=` attributes it replaces cannot be
  used by a host that enforces a Content-Security-Policy: `script-src` has no nonce or hash that
  applies to an inline event handler, so the attribute itself is the violation.

  ## Options
  - `:columns` - Number of grid columns (3, 4, 6, or 8)
  - `:overlay_action` - the action drawn as the star over the thumbnail (default `:toggle_featured`)
  - `:primary_action` - the action drawn wide and labelled (default `:edit`)

  ## Performance
  Uses `@static.*` for columns, ui_adapter, etc. (no re-render on user interaction)
  Uses `@state.*` for page, filter_values, etc. (re-renders when changed)

  See `MishkaGervaz.Table.Behaviours.Template`,
  `MishkaGervaz.Table.Templates.Shared`,
  `MishkaGervaz.Table.Templates.Table` (sibling), and
  `MishkaGervaz.UIAdapters.MediaGallery` (paired UI adapter).
  """

  use MishkaGervaz.Table.Behaviours.Template
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers,
    only: [dynamic_component: 1, get_visible_columns: 2, accessible?: 2]

  alias MishkaGervaz.Table.Templates.Shared
  alias Phoenix.LiveView.JS

  @impl true
  def name, do: :media_gallery

  @impl true
  def label, do: "Gallery"

  @doc """
  The switcher draws this glyph for the gallery view.

  A grid of squares rather than a photo, matching every other card view in the admin so the
  Table/Cards switch reads the same wherever it appears. Only the switcher asks for this.
  """
  @impl true
  def icon, do: "hero-squares-2x2"

  @impl true
  def description, do: "Image and media gallery with thumbnails"

  @impl true
  def features do
    [:filter, :select, :bulk_actions, :paginate, :expand]
  end

  @impl true
  def default_options do
    [columns: 6, overlay_action: :toggle_featured, primary_action: :edit]
  end

  @impl true
  def render(assigns) do
    static = %{assigns.static | ui_adapter: gallery_ui_adapter(assigns.static.ui_adapter)}
    state = assigns.state
    features = static.features
    assigns = assign(assigns, :static, static)

    show_checkboxes =
      :select in features and
        static.bulk_actions != [] and
        Shared.has_visible_bulk_actions?(static.bulk_actions, state.archive_status)

    accessible_filters = Enum.filter(static.filters, &accessible?(&1, state))

    show_filters =
      (accessible_filters != [] or state.supports_archive) and :filter in features

    show_pagination = :paginate in features
    show_bulk_actions = :bulk_actions in features and show_checkboxes

    assigns =
      assigns
      |> assign(:show_checkboxes, show_checkboxes)
      |> assign(:show_filters, show_filters)
      |> assign(:show_pagination, show_pagination)
      |> assign(:show_bulk_actions, show_bulk_actions)
      |> assign(:features, features)

    ~H"""
    <div id={@static.id} class="mishka-gervaz-media-gallery">
      <div :if={@state.has_initial_data? or @state.loading == :loaded}>
        <.render_header static={@static} state={@state} myself={@myself} />

        <.render_filters :if={@show_filters} static={@static} state={@state} myself={@myself} />

        <.render_selection_toolbar
          :if={@show_checkboxes}
          static={@static}
          state={@state}
          myself={@myself}
        />

        <.render_bulk_actions
          :if={@show_bulk_actions}
          static={@static}
          state={@state}
          myself={@myself}
        />

        <div class="relative isolate">
          <.render_loading_overlay
            :if={
              @state.has_initial_data? and @state.loading == :loading and
                @state.loading_type == :reset
            }
            static={@static}
            state={@state}
          />

          <div id={"#{@static.stream_name}"} phx-update="stream" class={gallery_classes(@static)}>
            <.render_item
              :for={{id, record} <- @stream}
              id={id}
              record={record}
              static={@static}
              state={@state}
              show_checkboxes={@show_checkboxes}
              myself={@myself}
            />
          </div>
        </div>

        <.render_empty :if={@empty?} static={@static} state={@state} myself={@myself} />

        <.render_pagination :if={@show_pagination} static={@static} state={@state} myself={@myself} />
      </div>
    </div>
    """
  end

  @impl true
  def render_header(assigns) do
    assigns = assign(assigns, :total_count, assigns.state.total_count || 0)

    ~H"""
    <div class="mb-[14px] flex flex-wrap items-center justify-between gap-4">
      <span class="text-[12.5px] font-semibold text-[#8a877f]">
        {dngettext("mishka_gervaz", "%{count} file", "%{count} files", @total_count,
          count: @total_count
        )}
      </span>
      <div class="flex items-center gap-[10px]">
        <.dynamic_component
          :if={@state.supports_archive}
          module={@static.ui_adapter}
          function={:archive_toggle}
          table_id={@static.id}
          archive_status={@state.archive_status}
          myself={@myself}
        />
        <Shared.render_template_switcher
          :if={@static.switchable_templates not in [nil, []]}
          switchable_templates={@static.switchable_templates}
          current_template={@state.template}
          ui_adapter={@static.ui_adapter}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  defp render_selection_toolbar(assigns) do
    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:id, assigns.static.id <> "-gallery-select-all")
      |> assign(:name, "select_all_gallery")
      |> assign(:value, "all")
      |> assign(:checked, assigns.state.select_all?)
      |> assign(
        :class,
        "gervaz-select-all-checkbox size-4 cursor-pointer rounded accent-[#5b57d6]"
      )
      |> assign(:label, dgettext("mishka_gervaz", "Select all"))

    assigns = assign(assigns, :checkbox_assigns, checkbox_assigns)

    ~H"""
    <div class="mb-3.5 flex items-center gap-4 px-0.5 [&_label]:flex [&_label]:cursor-pointer [&_label]:items-center [&_label]:gap-[9px] [&_span]:text-[12.5px]! [&_span]:font-semibold [&_span]:text-[#5c5a54]">
      <.dynamic_component
        module={@static.ui_adapter}
        function={:checkbox}
        phx-click={toggle_all_js(@state.select_all?, @static.id)}
        phx-target={@myself}
        {@checkbox_assigns}
      />
    </div>
    """
  end

  defp toggle_all_js(current_select_all, scope) do
    js = JS.push("toggle_select_all")

    if current_select_all do
      Shared.uncheck_all(js, scope)
    else
      Shared.check_all_gallery(js, scope)
    end
  end

  @impl true
  def render_item(assigns) do
    static = %{assigns.static | ui_adapter: gallery_ui_adapter(assigns.static.ui_adapter)}
    state = assigns.state
    record = assigns.record
    assigns = assign(assigns, :static, static)

    is_checked = selected?(state, record)

    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:name, "select_media")
      |> assign(:value, record.id)
      |> assign(:checked, is_checked)
      |> assign(:class, "gervaz-media-checkbox size-4 cursor-pointer rounded accent-[#5b57d6]")

    groups =
      static.row_actions
      |> Shared.non_accordion_actions()
      |> Enum.filter(&Shared.action_visible?(&1, record, state))
      |> split_actions(static, featured?(record))

    image_url = thumbnail_url(static, state, record)

    assigns =
      assigns
      |> assign(:is_checked, is_checked)
      |> assign(:checkbox_assigns, checkbox_assigns)
      |> assign(:primary_actions, groups.primary)
      |> assign(:secondary_actions, groups.secondary)
      |> assign(:custom_card_class, get_custom_card_class(static, record))
      |> assign(:image_url, image_url)
      |> assign(:is_image, is_image_url?(image_url))
      |> assign(:tint, tint(record))
      |> assign(:media_type, media_type(record))
      |> assign(:ext, media_ext(record))
      |> assign(:filename, media_name(record))
      |> assign(:size_label, media_size(record))
      |> assign(:category, media_category(record))
      |> assign(:date_label, media_date(record))
      |> assign(:featured?, featured?(record))
      |> assign(:star_actions, groups.overlay)

    ~H"""
    <div
      id={@id}
      class={[
        "group overflow-hidden rounded-[14px] border bg-white shadow-[0_1px_2px_rgba(30,28,24,0.04)] transition-colors",
        cond do
          @is_checked -> "border-[#dcdbf5] ring-1 ring-[#5b57d6]"
          @featured? -> "border-[#f0e2c4] ring-1 ring-[#e6b422]"
          true -> "border-[#ecebe6] hover:border-[#dcdbf5]"
        end,
        @custom_card_class
      ]}
    >
      <div class={["relative isolate aspect-square", @tint]}>
        <span class="absolute inset-0 flex items-center justify-center">
          <span class="grid size-[52px] place-items-center rounded-[14px] bg-white shadow-[0_2px_6px_rgba(30,28,24,0.06)]">
            <.type_glyph type={@media_type} class="size-[26px]" />
          </span>
        </span>

        <div
          :if={@image_url && @is_image}
          id={"#{@id}-thumb"}
          phx-hook="MediaThumb"
          phx-update="ignore"
          data-loaded-background="#fff"
          class="contents"
        >
          <img
            src={@image_url}
            alt=""
            loading="lazy"
            class="absolute inset-0 size-full object-cover"
          />
        </div>

        <span
          :if={@ext}
          class="absolute right-[10px] top-[10px] rounded-md bg-white/85 px-[7px] py-[3px] text-[9px] font-bold uppercase tracking-[0.05em] text-[#5c5a54] shadow-[0_1px_2px_rgba(30,28,24,0.08)]"
        >
          {@ext}
        </span>

        <span :if={@show_checkboxes} class="absolute left-[10px] top-[10px] z-20">
          <.dynamic_component
            module={@static.ui_adapter}
            function={:checkbox}
            phx-click="toggle_select"
            phx-value-id={@record.id}
            phx-target={@myself}
            {@checkbox_assigns}
          />
        </span>

        <div
          :if={@star_actions != [] or @featured?}
          title={@star_actions == [] && "Featured"}
          class={[
            "absolute bottom-2 right-2 z-20 grid size-7 place-items-center rounded-lg bg-white/85 shadow-[0_1px_2px_rgba(30,28,24,0.08)]",
            "[&>div]:contents [&_.lbl]:hidden [&_button]:size-full [&_button]:rounded-lg [&_button]:border-0 [&_button]:bg-transparent [&_button]:text-inherit [&_button]:hover:text-inherit",
            (@featured? && "text-[#e6b422]") || "text-[#c3c0b8] hover:text-[#e6b422]"
          ]}
        >
          <Shared.render_row_actions
            :if={@star_actions != []}
            row_actions={@star_actions}
            record={@record}
            static={@static}
            state={@state}
            myself={@myself}
          />
          <.dynamic_component
            :if={@star_actions == []}
            module={@static.ui_adapter}
            function={:icon}
            name="hero-star-solid"
            class="size-[15px]"
          />
        </div>
      </div>

      <div class="px-[13px] py-3">
        <div class="truncate text-[12.5px] font-semibold text-[#1b1a18]" title={@filename}>
          {@filename}
        </div>

        <div class="mt-[5px] flex items-center gap-2 text-[11px]">
          <span class="flex-none font-['Space_Grotesk'] font-semibold text-[#8a877f]">
            {@size_label}
          </span>
          <span :if={@category} class="size-[3px] flex-none rounded-full bg-[#c3c0b8]"></span>
          <span :if={@category} class="min-w-0 truncate font-medium text-[#a8a5a0]">
            {@category}
          </span>
        </div>

        <div
          :if={@date_label}
          class="mt-1.5 font-['Space_Grotesk'] text-[10px] font-medium text-[#c3c0b8]"
        >
          {@date_label}
        </div>

        <div
          :if={@primary_actions != [] or @secondary_actions != []}
          class="mt-3 flex items-center gap-1.5"
        >
          <div
            :if={@primary_actions != []}
            class="contents [&>div]:contents [&_.lbl]:truncate [&_button]:flex [&_button]:w-auto [&_button]:min-w-0 [&_button]:flex-1 [&_button]:items-center [&_button]:justify-center [&_button]:gap-1.5 [&_button]:px-2.5 [&_button]:text-[11.5px] [&_button]:font-bold [&_button]:text-[#5c5a54]"
          >
            <Shared.render_row_actions
              row_actions={@primary_actions}
              record={@record}
              static={@static}
              state={@state}
              myself={@myself}
            />
          </div>

          <div :if={@secondary_actions != []} class="contents [&>div]:contents [&_.lbl]:hidden">
            <Shared.render_row_actions
              row_actions={@secondary_actions}
              record={@record}
              static={@static}
              state={@state}
              myself={@myself}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  The card's three action groups: the star over the thumbnail, the one wide button, and the squares.

  A card has room for one action that says what it does; the rest are glyphs. Which action gets
  which part is a `template_options` decision, defaulting to the names the media resource uses:

      presentation do
        template_options [overlay_action: :pin, primary_action: :open]
      end

  A resource whose `row_actions_layout` PLACES an action — inline, or behind a dropdown — has
  already said where its actions go, so this hands them all back as one row rather than overruling
  it. An empty layout is not an answer; every resource with row actions has one of those.

  `featured?` fills the overlay's star. The DSL can only name one icon, because a resource cannot
  know which record its action will be drawn on; the template can, so the file that IS featured
  wears the filled star and the rest wear the outline.
  """
  @spec split_actions([map()], map(), boolean()) :: %{
          overlay: [map()],
          primary: [map()],
          secondary: [map()]
        }
  def split_actions(actions, static, featured? \\ false) do
    if placed_by_layout?(static) do
      %{overlay: [], primary: [], secondary: actions}
    else
      options = Map.get(static, :template_options) || []
      {overlay, rest} = Enum.split_with(actions, &named?(&1, options, :overlay_action))
      {primary, secondary} = Enum.split_with(rest, &named?(&1, options, :primary_action))

      %{overlay: fill_star(overlay, featured?), primary: primary, secondary: secondary}
    end
  end

  defp placed_by_layout?(static) do
    layout = Map.get(static, :row_actions_layout)
    dropdowns = Map.get(static, :row_action_dropdowns) || []

    layout != nil and (dropdowns != [] or (layout[:inline] || []) != [])
  end

  defp named?(action, options, key) do
    action[:name] == Keyword.get(options, key, Keyword.fetch!(default_options(), key))
  end

  defp fill_star(actions, false), do: actions

  defp fill_star(actions, true) do
    Enum.map(actions, fn
      %{ui: %{icon: "hero-star"} = ui} = action -> %{action | ui: %{ui | icon: "hero-star-solid"}}
      action -> action
    end)
  end

  @doc """
  Whether this record is selected, under either selection mode.

  `select_all?` inverts the meaning of the set: everything is chosen except what is in
  `excluded_ids`. Getting that backwards ticks every box the reader has just cleared.
  """
  @spec selected?(map(), map()) :: boolean()
  def selected?(%{select_all?: true, excluded_ids: excluded}, record),
    do: not MapSet.member?(excluded, record.id)

  def selected?(%{selected_ids: selected}, record), do: MapSet.member?(selected, record.id)

  @doc """
  The URL of a record's thumbnail, or nil when it has none to show.

  THE CARD IS THIS TEMPLATE'S, WHEREVER IT IS DRAWN. A resource gates its gallery columns with
  `visible fn state -> state.template.name() == :media_gallery end`, which is the right thing to
  write — but a template that BORROWS the card, by delegating `render_item/1` or by calling this,
  has a different name in `state`, so the first visible column is no longer the thumbnail and every
  file falls back to its type glyph. The page builder's Assets sheet showed a JPEG as a document
  icon for exactly this reason. Borrowing the card borrows its column contract, so the question is
  asked as this template.
  """
  @spec thumbnail_url(map(), map(), map()) :: String.t() | nil
  def thumbnail_url(static, state, record) do
    static.columns
    |> get_visible_columns(%{state | template: __MODULE__})
    |> List.first()
    |> case do
      nil -> nil
      column -> column |> get_column_value(record, state) |> cache_bust_url(record)
    end
  end

  @tints %{
    images: "bg-[#eef1fc] text-[#4f4bcc]",
    videos: "bg-[#fbe9e7] text-[#b3433a]",
    documents: "bg-[#eaf6ee] text-[#177a53]"
  }

  @doc "The background wash a file's type gets. See `media_type/1`."
  @spec tint(map()) :: String.t()
  def tint(record), do: Map.get(@tints, media_type(record), "bg-[#f2f1ec] text-[#8a877f]")

  attr :type, :atom, default: nil
  attr :class, :string, default: "size-[26px]"

  @doc """
  The glyph a file wears when there is no thumbnail to show instead.

  Public because the sheet's list draws the same file smaller — see
  `MishkaCmsCoreWeb.Templates.AssetsList` in the CMS.
  """
  def type_glyph(%{type: :images} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.7"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={@class}
      aria-hidden="true"
    >
      <rect x="3" y="4" width="18" height="16" rx="2" /><circle cx="8.5" cy="9" r="1.6" /><path d="m3 16 5-4 4 3 4-4 5 4" />
    </svg>
    """
  end

  def type_glyph(%{type: :videos} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.7"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={@class}
      aria-hidden="true"
    >
      <rect x="3" y="5" width="18" height="14" rx="2.5" /><path d="M10 9.5v5l4-2.5z" />
    </svg>
    """
  end

  def type_glyph(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.7"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={@class}
      aria-hidden="true"
    >
      <path d="M8 3h6l4 4v13a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z" /><path d="M14 3v5h4M9.5 13h5M9.5 16h4" />
    </svg>
    """
  end

  @doc "A record's media type — `:images`, `:videos`, `:documents`, or nil."
  @spec media_type(map()) :: atom() | nil
  def media_type(%{type: type}) when is_atom(type) and not is_nil(type), do: type
  def media_type(_record), do: nil

  @doc """
  A file's extension as declared by its `format` attribute, or `nil`.
  """
  def media_ext(%{format: format}) when is_binary(format) and format != "", do: format
  def media_ext(_record), do: nil

  @doc """
  A file's display name, with its extension when the record carries one.

      iex> media_name(%{name: "cover", format: "png"})
      "cover.png"
  """
  def media_name(%{name: name, format: format})
      when is_binary(name) and is_binary(format),
      do: "#{name}.#{format}"

  def media_name(%{name: name}) when is_binary(name), do: name
  def media_name(_record), do: "Untitled"

  @doc """
  A file's size, humanised, or an em dash when the record has none.

      iex> media_size(%{size: 2048})
      "2.0 KB"
  """
  def media_size(%{size: size}) when is_integer(size),
    do: MishkaGervaz.Helpers.format_filesize(size)

  def media_size(_record), do: "—"

  @doc """
  The name of the category a file belongs to, or `nil`.

  Only one of the two category relationships is ever loaded — a tenant's own, or the master
  alias that bypasses tenancy — so both are tried and whichever holds a record wins.
  """
  def media_category(record) do
    Enum.find_value([:media_category, :master_media_category], fn key ->
      case Map.get(record, key) do
        %{name: name} when is_binary(name) -> name
        _absent -> nil
      end
    end)
  end

  @doc """
  The date a file was added, formatted for a card, or `nil` when it is not loaded.

      iex> media_date(%{inserted_at: ~U[2026-08-13 10:00:00Z]})
      "Aug 13, 2026"
  """
  def media_date(%{inserted_at: %DateTime{} = at}), do: Calendar.strftime(at, "%b %d, %Y")
  def media_date(%{inserted_at: %NaiveDateTime{} = at}), do: Calendar.strftime(at, "%b %d, %Y")
  def media_date(_record), do: nil

  @doc "Whether this file is featured — the star, and the card's gold ring."
  @spec featured?(map()) :: boolean()
  def featured?(%{featured: true}), do: true
  def featured?(_record), do: false

  defp get_column_value(column, record, state) do
    cond do
      column.static and is_function(column.render, 1) ->
        required_fields = column.requires || [column.name]
        field_map = Map.new(required_fields, fn field -> {field, Map.get(record, field)} end)
        column.render.(field_map)

      is_function(column.render, 1) ->
        value = Map.get(record, column.name)
        column.render.(value)

      is_function(column.render, 2) ->
        value = Map.get(record, column.name)
        column.render.(value, state)

      true ->
        Map.get(record, column.name)
    end
  end

  defp is_image_url?(nil), do: false

  defp is_image_url?("data:image/" <> _), do: true

  defp is_image_url?(url) when is_binary(url) do
    path = url |> String.split("?") |> List.first()
    ext = path |> String.downcase() |> Path.extname()
    ext in ~w(.jpg .jpeg .png .gif .webp .svg)
  end

  defp is_image_url?(_), do: false

  defp cache_bust_url(nil, _record), do: nil

  defp cache_bust_url(url, record) when is_binary(url) do
    case Map.get(record, :updated_at) do
      %DateTime{} = dt -> url <> "?v=#{DateTime.to_unix(dt)}"
      _ -> url
    end
  end

  defp cache_bust_url(url, _record), do: url

  @impl true
  def render_empty(assigns) do
    empty_state = Map.get(assigns.static.config, :empty_state, %{})
    default_empty_state = Map.put_new(empty_state, :icon, "hero-photo")
    assigns = assign(assigns, :empty_state, default_empty_state)
    Shared.render_empty_state(assigns)
  end

  @impl true
  def render_loading(assigns) do
    loading_text =
      (assigns[:static] && assigns.static.pagination_ui.loading_text) ||
        dgettext("mishka_gervaz", "Loading...")

    assigns = assign(assigns, :loading_text, loading_text)

    ~H"""
    <.dynamic_component
      module={@static.ui_adapter}
      function={:loading_state}
      type={:initial}
      style={:spinner}
      text={@loading_text}
      class="py-12 text-center"
    />
    """
  end

  @impl true
  def render_filters(assigns) do
    all_filters =
      Shared.merge_relation_filter_state(
        assigns.static.filters,
        assigns.state.relation_filter_state || %{}
      )

    accessible = Enum.filter(all_filters, &accessible?(&1, assigns.state))

    grid_filters =
      Enum.filter(accessible, &(&1.name in [:search, :type, :site_id]))
      |> Enum.sort_by(&Enum.find_index([:search, :type, :site_id], fn n -> n == &1.name end))

    assigns =
      assigns
      |> assign(:all_filters, all_filters)
      |> assign(:grid_filters, grid_filters)
      |> assign(:featured_filter, Enum.find(accessible, &(&1.name == :featured)))

    ~H"""
    <form
      :if={@grid_filters != [] or @featured_filter}
      id={"#{@static.stream_name}-filter"}
      phx-change="filter"
      phx-target={@myself}
      class="mb-[14px] flex flex-wrap items-end gap-[12px]"
    >
      <Shared.render_filter
        :for={filter <- @grid_filters}
        filter={filter}
        all_filters={@all_filters}
        state={@state}
        static={@static}
        myself={@myself}
      />
      <Shared.render_filter
        :if={@featured_filter}
        filter={@featured_filter}
        all_filters={@all_filters}
        state={@state}
        static={@static}
        myself={@myself}
      />
    </form>
    """
  end

  defp render_loading_overlay(assigns) do
    loading_text =
      assigns.static.pagination_ui.loading_text || dgettext("mishka_gervaz", "Loading...")

    assigns = assign(assigns, :loading_text, loading_text)

    ~H"""
    <div class="absolute inset-0 bg-white/70 flex items-center justify-center z-20 min-h-[200px]">
      <.dynamic_component
        module={@static.ui_adapter}
        function={:loading_state}
        type={:overlay}
        style={:spinner}
        text={@loading_text}
        class="flex items-center gap-2 bg-white px-4 py-2 rounded-lg shadow-md"
      />
    </div>
    """
  end

  defp gallery_classes(static) do
    options = static.template_options || default_options()

    [
      "grid items-start gap-4",
      track_class(Keyword.get(options, :columns, 4)),
      Keyword.get(options, :class)
    ]
    |> Enum.filter(& &1)
  end

  defp track_class(columns) when columns <= 3,
    do: "grid-cols-[repeat(auto-fill,minmax(min(100%,220px),1fr))]"

  defp track_class(4), do: "grid-cols-[repeat(auto-fill,minmax(min(100%,190px),1fr))]"
  defp track_class(_more), do: "grid-cols-[repeat(auto-fill,minmax(min(100%,150px),1fr))]"

  defp get_custom_card_class(static, record) do
    case get_in(static.config, [:row, :class, :apply]) do
      apply_fn when is_function(apply_fn, 1) -> apply_fn.(record)
      _ -> nil
    end
  end

  @doc "The adapter a media card is drawn with, unless the resource named one of its own."
  @spec gallery_ui_adapter(module()) :: module()
  def gallery_ui_adapter(MishkaGervaz.UIAdapters.Tailwind),
    do: MishkaGervaz.UIAdapters.MediaGallery

  def gallery_ui_adapter(user_adapter), do: user_adapter
end

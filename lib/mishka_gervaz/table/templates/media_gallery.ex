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

  ## Options
  - `:columns` - Number of grid columns (3, 4, 6, or 8)

  ## Performance
  Uses `@static.*` for columns, ui_adapter, etc. (no re-render on user interaction)
  Uses `@state.*` for page, filter_values, etc. (re-renders when changed)
  """

  use MishkaGervaz.Table.Behaviours.Template
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers, only: [dynamic_component: 1, get_visible_columns: 2]

  alias MishkaGervaz.Table.Templates.Shared
  alias Phoenix.LiveView.JS

  @impl true
  def name, do: :media_gallery

  @impl true
  def label, do: "Gallery"

  @impl true
  def icon, do: "hero-photo"

  @impl true
  def description, do: "Image and media gallery with thumbnails"

  @impl true
  def features do
    [:filter, :select, :bulk_actions, :paginate, :expand]
  end

  @impl true
  def default_options do
    [columns: 6]
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

    show_filters = static.filters != [] and :filter in features
    show_pagination = :paginate in features
    show_bulk_actions = :bulk_actions in features and show_checkboxes

    assigns =
      assigns
      |> assign(:show_checkboxes, show_checkboxes)
      |> assign(:show_filters, show_filters)
      |> assign(:show_pagination, show_pagination)
      |> assign(:show_bulk_actions, show_bulk_actions)
      |> assign(:features, features)

    show_template_switcher =
      static.switchable_templates != nil and static.switchable_templates != []

    assigns =
      assigns
      |> assign(:show_template_switcher, show_template_switcher)

    ~H"""
    <div class="mishka-gervaz-media-gallery">
      <.render_initial_loading
        :if={!@state.has_initial_data? and @state.loading in [:initial, :loading]}
        static={@static}
        state={@state}
      />

      <div :if={@state.has_initial_data? or @state.loading == :loaded}>
        <.render_header
          :if={@show_template_switcher}
          static={@static}
          state={@state}
          myself={@myself}
        />

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

        <div class="relative" style="isolation: isolate;">
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
    total_count = assigns.state.total_count || 0

    header_class =
      (assigns.static.theme && assigns.static.theme[:header_class]) ||
        "flex items-center justify-between mb-4"

    assigns =
      assigns
      |> assign(:total_count, total_count)
      |> assign(:header_class, header_class)

    ~H"""
    <div class={@header_class}>
      <div class="text-sm text-gray-500">
        {dngettext("mishka_gervaz", "%{count} file", "%{count} files", @total_count,
          count: @total_count
        )}
      </div>
      <Shared.render_template_switcher
        switchable_templates={@static.switchable_templates}
        current_template={@state.template}
        myself={@myself}
      />
    </div>
    """
  end

  defp render_selection_toolbar(assigns) do
    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:id, "gallery-select-all")
      |> assign(:name, "select_all_gallery")
      |> assign(:value, "all")
      |> assign(:checked, assigns.state.select_all?)
      |> assign(:class, "gervaz-select-all-checkbox")
      |> assign(:label, dgettext("mishka_gervaz", "Select all"))

    toolbar_class =
      (assigns.static.theme && assigns.static.theme[:selection_toolbar_class]) ||
        "flex items-center gap-4 mb-4 py-2 px-3 bg-gray-50 rounded"

    assigns =
      assigns
      |> assign(:checkbox_assigns, checkbox_assigns)
      |> assign(:toolbar_class, toolbar_class)

    ~H"""
    <div class={@toolbar_class}>
      <.dynamic_component
        module={@static.ui_adapter}
        function={:checkbox}
        phx-click={toggle_all_js(@state.select_all?)}
        phx-target={@myself}
        {@checkbox_assigns}
      />
    </div>
    """
  end

  defp toggle_all_js(current_select_all) do
    js = JS.push("toggle_select_all")

    if current_select_all do
      Shared.uncheck_all(js)
    else
      Shared.check_all_gallery(js)
    end
  end

  @impl true
  def render_item(assigns) do
    static = assigns.static
    state = assigns.state
    record = assigns.record

    visible_columns = get_visible_columns(static.columns, state)

    {thumbnail_column, info_columns} =
      case visible_columns do
        [first | rest] -> {first, rest}
        [] -> {nil, []}
      end

    is_checked =
      if state.select_all? do
        not MapSet.member?(state.excluded_ids, record.id)
      else
        MapSet.member?(state.selected_ids, record.id)
      end

    checkbox_assigns =
      %{__changed__: %{}}
      |> assign(:name, "select_media")
      |> assign(:value, record.id)
      |> assign(:checked, is_checked)
      |> assign(:class, "gervaz-media-checkbox bg-white rounded")

    visible_row_actions =
      Enum.filter(static.row_actions, fn action ->
        Shared.action_visible?(action, record, state)
      end)

    custom_card_class = get_custom_card_class(static, record)

    assigns =
      assigns
      |> assign(:thumbnail_column, thumbnail_column)
      |> assign(:info_columns, info_columns)
      |> assign(:is_checked, is_checked)
      |> assign(:checkbox_assigns, checkbox_assigns)
      |> assign(:visible_row_actions, visible_row_actions)
      |> assign(:custom_card_class, custom_card_class)

    ~H"""
    <div id={@id} class={thumbnail_wrapper_classes(@static, @custom_card_class)}>
      <div
        class={thumbnail_classes(@static, @is_checked)}
        phx-click="expand"
        phx-value-id={@record.id}
        phx-target={@myself}
      >
        <.render_thumbnail
          :if={@thumbnail_column}
          record={@record}
          column={@thumbnail_column}
          state={@state}
          ui_adapter={@static.ui_adapter}
        />

        <div class="absolute inset-0 bg-black bg-opacity-0 hover:bg-opacity-30 transition-all flex items-center justify-center opacity-0 hover:opacity-100">
          <Shared.render_row_actions
            row_actions={@visible_row_actions}
            record={@record}
            static={@static}
            state={@state}
            myself={@myself}
          />
        </div>

        <div :if={@show_checkboxes} class="absolute top-2 left-2">
          <.dynamic_component
            module={@static.ui_adapter}
            function={:checkbox}
            phx-click="toggle_select"
            phx-value-id={@record.id}
            phx-target={@myself}
            {@checkbox_assigns}
          />
        </div>
      </div>

      <div :if={@info_columns != []} class="mt-2 px-1 space-y-0.5">
        <.render_info_column
          :for={column <- @info_columns}
          record={@record}
          column={column}
          state={@state}
        />
      </div>
    </div>
    """
  end

  defp render_thumbnail(assigns) do
    column = assigns.column
    record = assigns.record

    image_url = get_column_value(column, record, assigns.state) |> cache_bust_url(record)
    is_image = is_image_url?(image_url)

    assigns =
      assigns
      |> assign(:image_url, image_url)
      |> assign(:is_image, is_image)

    ~H"""
    <%= if @image_url && @is_image do %>
      <div class="w-full aspect-square relative bg-gray-400">
        <span class="absolute inset-0 flex items-center justify-center text-white text-sm font-medium">
          No Image
        </span>
        <img
          src={@image_url}
          alt=""
          class="absolute inset-0 w-full h-full object-cover"
          loading="lazy"
          onload="this.previousElementSibling.style.display='none';this.style.backgroundColor='white';"
          onerror="this.remove();"
        />
      </div>
    <% else %>
      <div class="w-full aspect-square flex items-center justify-center bg-gray-100">
        <.file_type_icon url={@image_url} ui_adapter={@ui_adapter} />
      </div>
    <% end %>
    """
  end

  defp render_info_column(assigns) do
    column = assigns.column
    record = assigns.record
    value = get_column_value(column, record, assigns.state)

    formatted_value =
      case column.format do
        func when is_function(func, 1) -> func.(value)
        _ -> value
      end

    is_rendered = is_struct(formatted_value, Phoenix.LiveView.Rendered)
    column_class = if is_map(column.ui), do: column.ui[:class], else: nil

    assigns =
      assigns
      |> assign(:value, formatted_value)
      |> assign(:is_rendered, is_rendered)
      |> assign(:label, column.label)
      |> assign(:column_class, column_class)

    ~H"""
    <div :if={@is_rendered} class={info_column_classes(@column_class)}>
      {@value}
    </div>
    <p
      :if={!@is_rendered}
      class={info_column_classes(@column_class, "truncate")}
      title={to_string(@value)}
    >
      {@value}
    </p>
    """
  end

  defp info_column_classes(custom_class, extra \\ nil) do
    ["text-sm text-gray-700", extra, custom_class]
    |> Enum.filter(& &1)
  end

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

  defp file_type_icon(assigns) do
    assigns = assign(assigns, :icon_name, get_file_icon_from_url(assigns.url))

    ~H"""
    <.dynamic_component
      module={@ui_adapter}
      function={:icon}
      name={@icon_name}
      class="h-12 w-12 text-gray-400"
    />
    """
  end

  defp get_file_icon_from_url(nil), do: "hero-document"

  defp get_file_icon_from_url(url) when is_binary(url) do
    ext = url |> String.downcase() |> Path.extname() |> String.trim_leading(".")

    case ext do
      f when f in ~w(jpg jpeg png gif webp svg bmp ico tiff) -> "hero-photo"
      f when f in ~w(mp4 webm mov avi mkv) -> "hero-video-camera"
      f when f in ~w(mp3 wav ogg flac aac m4a) -> "hero-musical-note"
      "pdf" -> "hero-document-text"
      f when f in ~w(xls xlsx csv) -> "hero-table-cells"
      f when f in ~w(zip rar 7z tar gz) -> "hero-archive-box"
      f when f in ~w(doc docx txt rtf odt) -> "hero-document"
      _ -> "hero-document"
    end
  end

  defp get_file_icon_from_url(_), do: "hero-document"

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
    Shared.render_filters(assigns)
  end

  @impl true
  def render_bulk_actions(assigns) do
    Shared.render_bulk_actions(assigns)
  end

  @impl true
  def render_error(assigns) do
    error_state = Map.get(assigns.static.config, :error_state, %{})
    assigns = assign(assigns, :error_state, error_state)
    Shared.render_error_state(assigns)
  end

  @impl true
  def render_pagination(assigns) do
    pagination_type = get_in(assigns.static.config, [:pagination, :type]) || :numbered

    assigns =
      assigns
      |> assign(:pagination_type, pagination_type)
      |> assign(:loading_text, assigns.static.pagination_ui.loading_text)
      |> assign(:load_more_label, assigns.static.pagination_ui.load_more_label)

    Shared.render_pagination(assigns)
  end

  defp render_initial_loading(assigns) do
    loading_text =
      assigns.static.pagination_ui.loading_text || dgettext("mishka_gervaz", "Loading...")

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
    columns = Keyword.get(options, :columns, 6)
    custom_class = Keyword.get(options, :class)

    column_class =
      case columns do
        3 -> "sm:grid-cols-2 lg:grid-cols-3"
        4 -> "sm:grid-cols-3 lg:grid-cols-4"
        6 -> "sm:grid-cols-4 lg:grid-cols-6"
        8 -> "sm:grid-cols-5 lg:grid-cols-8"
        _ -> "sm:grid-cols-4 lg:grid-cols-6"
      end

    ["grid", column_class, "gap-4", custom_class]
    |> Enum.filter(& &1)
  end

  defp thumbnail_wrapper_classes(static, custom_class) do
    theme_row_class = static.theme && static.theme[:row_class]

    ["group", theme_row_class, custom_class]
    |> Enum.filter(& &1)
  end

  defp thumbnail_classes(_static, is_checked) do
    selected = if is_checked, do: "ring-2 ring-blue-500", else: ""

    [
      "relative rounded-lg overflow-hidden cursor-pointer aspect-square",
      selected
    ]
    |> Enum.filter(& &1)
  end

  defp get_custom_card_class(static, record) do
    case get_in(static.config, [:row, :class, :apply]) do
      apply_fn when is_function(apply_fn, 1) -> apply_fn.(record)
      _ -> nil
    end
  end

  defp gallery_ui_adapter(MishkaGervaz.UIAdapters.Tailwind),
    do: MishkaGervaz.UIAdapters.MediaGallery

  defp gallery_ui_adapter(user_adapter), do: user_adapter
end

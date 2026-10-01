defmodule MishkaGervaz.Table.Templates.StickyActionsTest do
  @moduledoc """
  On a screen 980px or wider the Actions column is pinned to the right edge of the table's frame,
  in the header and in every row, so the row actions stay in view while the columns before it
  scroll under it. Each Actions cell takes its row's colour, or the header's, over the frame's
  white, and draws a 1px line on its left only while the frame carries `data-overflowing`, which
  the app sets while the table scrolls sideways; the frame tells the app it is on the page with a
  `gervaz:table-frame-mounted` event. Below 980px the rows are cards and nothing is pinned.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.TranslatedDsl

  @admin %{id: "user-1", role: :admin}

  @records [
    %{id: "row-1", title: "Plain", slug: "plain", status: :published, featured: false},
    %{id: "row-2", title: "Tinted", slug: "tinted", status: :draft, featured: true},
    %{id: "row-3", title: "Selected", slug: "selected", status: :published, featured: false},
    %{id: "row-4", title: "Expanded", slug: "expanded", status: :draft, featured: false}
  ]

  @pinned ~w(min-[980px]:sticky min-[980px]:right-0 min-[980px]:z-10)
  @painted ~w|min-[980px]:bg-inherit min-[980px]:bg-[linear-gradient(#fff,#fff)] min-[980px]:bg-blend-multiply|
  @line "min-[980px]:in-data-overflowing:shadow-[inset_1px_0_0_#ecebe6]"
  @unconditional_line "min-[980px]:shadow-[inset_1px_0_0_#ecebe6]"
  @bleed ~w(min-[980px]:-my-[14px] min-[980px]:self-stretch min-[980px]:py-[14px])
  @raised "min-[980px]:has-[[aria-expanded=true]]:z-[11]"

  defp table_state(updates \\ []) do
    "sticky-actions"
    |> State.init(TranslatedDsl, @admin)
    |> State.update(Keyword.merge([loading: :loaded, has_initial_data?: true], updates))
  end

  defp with_static(state, changes), do: %{state | static: struct(state.static, changes)}

  # Tints a featured record through `row class`, selects row-3, and expands row-4.
  defp with_row_states(state) do
    config =
      Map.put(state.static.config, :row, %{
        class: %{apply: fn record -> if record.featured, do: "bg-[#fdf9ec]" end}
      })

    row_actions = state.static.row_actions ++ [%{name: :expand, type: :accordion}]

    state
    |> with_static(config: config, row_actions: row_actions)
    |> Map.merge(%{selected_ids: MapSet.new(["row-3"]), expanded_id: "row-4"})
  end

  defp render_table(state) do
    stream_name = state.static.stream_name

    render_component(&TableTemplate.render/1, %{
      static: state.static,
      state: state,
      stream: Enum.map(@records, &{"#{stream_name}-#{&1.id}", &1}),
      streams: %{stream_name => []},
      empty?: false,
      myself: nil,
      __changed__: %{}
    })
  end

  defp classes(class_attr), do: String.split(class_attr, " ", trim: true)

  defp header(html) do
    [_, thead, cell] =
      Regex.run(
        ~r/id="[^"]*-thead"\s+class="([^"]*)".*?<div data-role="gervaz-actions-header" class="([^"]*)"/s,
        html
      )

    {classes(thead), classes(cell)}
  end

  # Each row's own classes and its Actions cell's classes, by record id.
  defp rows(html) do
    ~r/<div id="[^"]*-(row-\d+)"\s+class="gervaz-row-group[^"]*">\s*<div class="(gervaz-row grid[^"]*)".*?<div data-role="gervaz-row-actions" class="([^"]*)"/s
    |> Regex.scan(html)
    |> Map.new(fn [_, id, row, cell] -> {id, {classes(row), classes(cell)}} end)
  end

  defp tracks(html) do
    ~r/style="grid-template-columns: ([^"]*);"/
    |> Regex.scan(html)
    |> Enum.map(fn [_, tracks] -> tracks end)
  end

  describe "on a screen 980px or wider" do
    test "the header's Actions cell is pinned to the frame's right edge, above the scrolled cells" do
      {_thead, cell} = table_state() |> render_table() |> header()

      for class <- @pinned, do: assert(class in cell)
    end

    test "every row's Actions cell is pinned the same way" do
      rows = table_state() |> with_row_states() |> render_table() |> rows()

      assert map_size(rows) == length(@records)

      for {_id, {_row, cell}} <- rows, class <- @pinned, do: assert(class in cell)
    end

    test "the header's Actions cell takes the header's colour over the frame's white" do
      {thead, cell} = table_state() |> render_table() |> header()

      assert "bg-[#faf9f6]" in thead
      for class <- @painted, do: assert(class in cell)
    end

    test "a row's Actions cell takes its row's colour in every state the row can be in" do
      rows = table_state() |> with_row_states() |> render_table() |> rows()

      {plain, _cell} = rows["row-1"]
      {tinted, _cell} = rows["row-2"]
      {selected, _cell} = rows["row-3"]
      {expanded, _cell} = rows["row-4"]

      assert "hover:bg-accent/50" in plain
      assert "bg-[#fdf9ec]" in tinted
      assert "bg-accent" in selected
      assert "hover:bg-accent/50" in expanded

      for {_id, {_row, cell}} <- rows, class <- @painted, do: assert(class in cell)
    end

    test "a row's Actions cell takes a theme's row colour and an archived view's rows alike" do
      state =
        table_state(archive_status: :archived)
        |> with_static(theme: %{row_class: "hover:bg-[#f7f6f3]"})

      rows = state |> render_table() |> rows()

      assert map_size(rows) == length(@records)

      for {_id, {row, cell}} <- rows do
        assert "hover:bg-[#f7f6f3]" in row
        for class <- @pinned ++ @painted, do: assert(class in cell)
      end
    end

    test "an expanded row keeps its details below the row, outside the pinned column" do
      html = table_state() |> with_row_states() |> render_table()

      [_, expanded_group] = String.split(html, ~s(sticky-actions_translated_dsl_stream-row-4"))
      [row, details | _] = String.split(expanded_group, ~s(<div class="border-b border-[#f0efea]))

      assert row =~ ~s(data-role="gervaz-row-actions")
      refute details =~ ~s(data-role="gervaz-row-actions")
    end

    test "each Actions cell draws a 1px line on its left in the table's border colour while the frame overflows" do
      html = table_state() |> with_row_states() |> render_table()
      {_thead, header_cell} = header(html)

      for cell <- [header_cell | Enum.map(rows(html), fn {_id, {_row, cell}} -> cell end)] do
        assert @line in cell
        refute @unconditional_line in cell
        refute Enum.any?(cell, &(&1 =~ "shadow-" and &1 != @line))
      end
    end

    test "the frame tells the app it is on the page, and names no hook the app must register" do
      html = table_state() |> render_table()

      [_, frame] = Regex.run(~r/<div([^>]*data-role="gervaz-table-frame"[^>]*)>/, html)

      assert frame =~ "phx-mounted="
      assert frame =~ "dispatch"
      assert frame =~ "gervaz:table-frame-mounted"
      refute frame =~ "phx-hook"
      refute frame =~ "data-overflowing"
    end

    test "each Actions cell reaches over its row's 14px of vertical padding" do
      html = table_state() |> with_row_states() |> render_table()
      {thead, header_cell} = header(html)

      assert "py-[14px]" in thead
      for class <- @bleed, do: assert(class in header_cell)

      for {_id, {row, cell}} <- rows(html) do
        assert "py-[14px]" in row
        for class <- @bleed, do: assert(class in cell)
      end
    end

    test "under a theme's own header class, the header cell is pinned but keeps its own height" do
      state = table_state() |> with_static(theme: %{header_class: "grid py-2 bg-[#f7f6f3]"})
      {thead, cell} = state |> render_table() |> header()

      assert "py-2" in thead
      for class <- @pinned ++ @painted, do: assert(class in cell)
      for class <- @bleed, do: refute(class in cell)
    end

    test "a row's Actions cell rises above the rows after it while a menu inside it is expanded" do
      html = table_state() |> render_table()

      for {_id, {_row, cell}} <- rows(html), do: assert(@raised in cell)
    end

    test "the columns keep the tracks they had, in the header and in every row" do
      state = table_state() |> with_row_states()

      unpinned =
        with_static(state, row_actions_layout: %{state.static.row_actions_layout | sticky: false})

      pinned_tracks = state |> render_table() |> tracks()

      assert length(pinned_tracks) == length(@records) + 1
      assert pinned_tracks |> Enum.uniq() |> length() == 1
      assert pinned_tracks == unpinned |> render_table() |> tracks()
    end

    test "the rows' container is never narrower than its columns" do
      assert table_state() |> render_table() =~ ~s(class="min-[980px]:min-w-min")
    end
  end

  describe "the row actions' dropdown" do
    defp dropdown(html) do
      [_, wrapper, trigger] =
        Regex.run(
          ~r/<div class="relative inline-block text-left"([^>]*)>\s*<button([^>]*)>/s,
          html
        )

      {wrapper, trigger}
    end

    test "its trigger says whether the menu is shown" do
      {_wrapper, trigger} = table_state() |> render_table() |> dropdown()

      [_, menu_id] = Regex.run(~r/aria-controls="([^"]*)"/, trigger)

      assert trigger =~ ~s(id="#{menu_id}-trigger")
      assert trigger =~ ~s(aria-haspopup="true")
      assert trigger =~ ~s(aria-expanded="false")
      assert trigger =~ "toggle_attr"
      assert trigger =~ "aria-expanded"
    end

    test "a click outside it hides the menu and marks the trigger collapsed" do
      {wrapper, trigger} = table_state() |> render_table() |> dropdown()

      [_, menu_id] = Regex.run(~r/aria-controls="([^"]*)"/, trigger)

      assert wrapper =~ "phx-click-away"
      assert wrapper =~ "hide"
      assert wrapper =~ "set_attr"
      assert wrapper =~ "#{menu_id}-trigger"
    end
  end

  describe "below 980px" do
    test "every class that pins, paints or lines the Actions cell applies from 980px up only" do
      html = table_state() |> with_row_states() |> render_table()
      {_thead, header_cell} = header(html)
      added = @pinned ++ @painted ++ @bleed ++ [@line, @raised]

      for cell <- [header_cell | Enum.map(rows(html), fn {_id, {_row, cell}} -> cell end)] do
        refute "sticky" in cell
        refute "z-10" in cell
        refute "bg-inherit" in cell

        for class <- cell, class not in added do
          refute String.starts_with?(class, "min-[980px]:")
        end
      end
    end

    test "a row's Actions cell keeps its card layout" do
      for {_id, {_row, cell}} <- table_state() |> render_table() |> rows() do
        assert "max-[980px]:px-0!" in cell
        assert "justify-end" in cell
      end
    end
  end

  describe "with actions_layout sticky false" do
    test "the Actions column scrolls with the rest of the row" do
      state = table_state()

      state =
        with_static(state, row_actions_layout: %{state.static.row_actions_layout | sticky: false})

      html = render_table(state)
      {_thead, header_cell} = header(html)

      for cell <- [header_cell | Enum.map(rows(html), fn {_id, {_row, cell}} -> cell end)] do
        refute Enum.any?(cell, &String.starts_with?(&1, "min-[980px]:"))
      end
    end
  end

  describe "with striped rows" do
    test "every second row is tinted under any colour of its own, so its Actions cell takes it" do
      state = table_state() |> with_static(template_options: [striped: true])

      [_, class_attr] =
        Regex.run(~r/phx-update="stream"\s+class="([^"]*)"/, render_table(state))

      row_group =
        class_attr
        |> String.replace("&gt;", ">")
        |> String.replace("&amp;", "&")
        |> classes()

      assert "[:where(&>div:nth-child(even)>.gervaz-row)]:bg-muted/20" in row_group
      refute "[&>div:nth-child(even)]:bg-muted/20" in row_group
    end
  end
end

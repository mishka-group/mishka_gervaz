defmodule MishkaGervaz.Table.Templates.ActionsTrackTest do
  @moduledoc """
  From 980px up the table is one grid that owns the column tracks. The header, the rows' stream,
  each row group and each row are subgrids of it, so every row lays its cells on the same tracks,
  and the Actions track is `max-content`: as wide as the widest Actions cell in the header and the
  rows, its buttons and 16px of padding on either side. Below 980px nothing of it applies and the
  rows are cards. A table wider than its frame shows a scrollbar to reach the rest.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.TranslatedDsl

  @admin %{id: "user-1", role: :admin}

  @records [
    %{id: "row-1", title: "Cat", slug: "cat", status: :published, featured: true},
    %{id: "row-2", title: "Dog", slug: "dog", status: :draft, featured: false}
  ]

  @subgrid ~w(min-[980px]:col-span-full min-[980px]:grid min-[980px]:grid-cols-subgrid)

  @row_group_cards ~w|max-[980px]:mb-3 max-[980px]:overflow-hidden max-[980px]:rounded-[14px] max-[980px]:border max-[980px]:border-[#ecebe6] max-[980px]:bg-white max-[980px]:shadow-[0_1px_3px_rgba(30,28,24,0.06)]|

  @row_cards ~w|max-[980px]:relative! max-[980px]:flex! max-[980px]:flex-col! max-[980px]:items-stretch! max-[980px]:gap-[12px] max-[980px]:p-4|

  defp table_state(updates \\ []) do
    "actions-track"
    |> State.init(TranslatedDsl, @admin)
    |> State.update(Keyword.merge([loading: :loaded, has_initial_data?: true], updates))
  end

  defp with_static(state, changes), do: %{state | static: struct(state.static, changes)}

  # Only the three inline actions, without the layout that adds the "More" dropdown.
  defp three_buttons(state) do
    with_static(state, row_actions_layout: nil, row_action_dropdowns: [])
  end

  # Adds an accordion, which expands row-2 into its details below the row.
  defp expanded(state) do
    state
    |> with_static(row_actions: state.static.row_actions ++ [%{name: :expand, type: :accordion}])
    |> Map.put(:expanded_id, "row-2")
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

  # The table grid's opening tag: its classes and its column tracks.
  defp table_grid(html, state) do
    [_, class, tracks] =
      Regex.run(
        ~r/<div id="#{state.static.stream_name}-grid" class="([^"]*)" style="grid-template-columns: ([^"]*);">/,
        html
      )

    {classes(class), tracks}
  end

  defp tracks(html, state) do
    {_class, tracks} = table_grid(html, state)
    tracks
  end

  defp thead_tag(html, state) do
    [tag] = Regex.run(~r/<div id="#{state.static.stream_name}-thead"[^>]*>/, html)
    tag
  end

  defp stream_classes(html, state) do
    [_, class] =
      Regex.run(
        ~r/<div id="#{state.static.stream_name}" phx-update="stream" class="([^"]*)">/,
        html
      )

    classes(class)
  end

  # Each row group's classes and its row's classes, by record id.
  defp rows(html) do
    ~r/<div id="[^"]*-(row-\d+)"\s+class="(gervaz-row-group[^"]*)">\s*<div class="(gervaz-row grid[^"]*)">/
    |> Regex.scan(html)
    |> Map.new(fn [_, id, group, row] -> {id, {classes(group), classes(row)}} end)
  end

  defp frame_class(html) do
    [_, class] = Regex.run(~r/data-role="gervaz-table-frame"\s+class="([^"]*)"/, html)
    class
  end

  describe "the table's grid" do
    test "owns the column tracks, from 980px up and never narrower than they need" do
      state = table_state()
      {class, _tracks} = state |> render_table() |> table_grid(state)

      assert class == ~w(min-[980px]:grid min-[980px]:min-w-min)
    end

    test "is the only element that declares column tracks" do
      state = table_state() |> expanded()
      html = render_table(state)

      assert [_one] = Regex.scan(~r/grid-template-columns/, html)
      refute thead_tag(html, state) =~ "style="
    end

    test "lays the header, the rows' stream, each row group and each row on its columns" do
      state = table_state()
      html = render_table(state)

      thead = Regex.run(~r/class="([^"]*)"/, thead_tag(html, state)) |> List.last() |> classes()
      for class <- @subgrid, do: assert(class in thead)
      for class <- @subgrid, do: assert(class in stream_classes(html, state))

      rows = rows(html)
      assert map_size(rows) == length(@records)

      for {_id, {group, row}} <- rows, class <- @subgrid do
        assert class in group
        assert class in row
      end
    end

    test "keeps the stream's container and its rows' ids for LiveView" do
      state = table_state()
      html = render_table(state)

      assert html =~ ~s(<div id="#{state.static.stream_name}" phx-update="stream")

      for record <- @records do
        assert html =~ ~s(<div id="#{state.static.stream_name}-#{record.id}")
      end
    end

    test "keeps each column's typed track, and a column's own width" do
      state = table_state()

      assert tracks(render_table(state), state) ==
               "44px minmax(190px,1.7fr) minmax(0,1fr) minmax(95px,0.8fr) minmax(90px,0.7fr) max-content"

      [title | columns] = state.static.columns
      title = %{title | ui: %{width: "minmax(180px,1.8fr)"}}
      state = with_static(state, columns: [title | columns])

      assert tracks(render_table(state), state) =~ ~r/^44px minmax\(180px,1\.8fr\) /
    end

    test "adds the expand caret's track before the columns" do
      state = table_state() |> expanded()

      assert tracks(render_table(state), state) =~ ~r/^44px 34px minmax\(190px,1\.7fr\) /
    end
  end

  describe "the Actions track" do
    test "is as wide as the widest Actions cell, with no width of its own" do
      for state <- [table_state(), three_buttons(table_state())] do
        tracks = state |> render_table() |> tracks(state)

        assert String.ends_with?(tracks, " max-content")
        refute tracks =~ ~r/\d+px,max-content/
      end
    end

    test "is absent when no row action is visible" do
      state = with_static(table_state(), row_actions: [], row_action_dropdowns: [])
      state = with_static(state, row_actions_layout: nil)
      html = render_table(state)

      refute tracks(html, state) =~ "max-content"
      refute html =~ ~s(data-role="gervaz-actions-header")
      refute html =~ ~s(data-role="gervaz-row-actions")
    end
  end

  describe "a row that spans the table" do
    test "an expanded row's details span every column, below the row" do
      html = table_state() |> expanded() |> render_table()

      [_, details] =
        Regex.run(~r/<div class="(border-b border-\[#f0efea\][^"]*)">/, html)

      assert "min-[980px]:col-span-full" in classes(details)
    end

    test "a row drawn by a row override spans every column" do
      state = table_state()

      config =
        Map.put(state.static.config, :row, %{
          overrides: [%{condition: &(&1.id == "row-2"), render: fn _assigns, _r, _c -> "Own" end}]
        })

      html = state |> with_static(config: config) |> render_table()

      assert html =~
               ~s(<div id="#{state.static.stream_name}-row-2" class="min-[980px]:col-span-full">)

      assert html =~ "gervaz-row-custom"
    end
  end

  describe "below 980px" do
    test "the grid and its subgrids apply from 980px up only" do
      state = table_state() |> expanded()
      html = render_table(state)
      {grid, _tracks} = table_grid(html, state)
      thead = Regex.run(~r/class="([^"]*)"/, thead_tag(html, state)) |> List.last() |> classes()
      stream = stream_classes(html, state)
      {groups, rows} = html |> rows() |> Map.values() |> Enum.unzip()

      assert Enum.all?(grid, &String.starts_with?(&1, "min-[980px]:"))
      refute "grid" in stream

      for classes <- [thead, stream | groups ++ rows] do
        refute "col-span-full" in classes
        refute "grid-cols-subgrid" in classes
      end

      for group <- groups, do: refute("grid" in group)
    end

    test "a row group and its row keep their card layout" do
      for {_id, {group, row}} <- table_state() |> render_table() |> rows() do
        assert "gervaz-row-group" in group
        for class <- @row_group_cards, do: assert(class in group)

        assert "grid" in row
        for class <- @row_cards, do: assert(class in row)
      end
    end
  end

  describe "the table's frame" do
    test "no longer hides its horizontal scrollbar" do
      class = render_table(table_state()) |> frame_class()

      refute class =~ "[scrollbar-width:none]"
      refute class =~ "-webkit-scrollbar]:hidden"
    end

    test "draws a thin scrollbar in the admin palette" do
      class = render_table(table_state()) |> frame_class()

      assert class =~ "overflow-x-auto"
      assert class =~ "[scrollbar-width:thin]"
      assert class =~ "[scrollbar-color:#d5d3cb_transparent]"
      assert class =~ "-webkit-scrollbar-thumb]:bg-[#d5d3cb]"
    end

    test "still lays rows out as cards, unscrolled, on a narrow screen" do
      class = render_table(table_state()) |> frame_class()

      assert class =~ "max-[980px]:overflow-visible!"
      assert class =~ "max-[980px]:border-0!"
    end
  end

  describe "a row action button" do
    test "dims and stops taking clicks while its click is pending" do
      html = render_table(three_buttons(table_state()))

      buttons = Regex.scan(~r/<button[^>]*class="grid size-\[30px\][^"]*"[^>]*>/, html)

      assert length(buttons) == 3 * length(@records)

      for [button] <- buttons do
        assert button =~ "phx-click-loading:opacity-70"
        assert button =~ "phx-click-loading:pointer-events-none"
      end
    end
  end
end

defmodule MishkaGervaz.Table.Templates.TabletCardsTest do
  @moduledoc """
  Below 980px the default table's rows are cards. On a tablet (641px to 980px) a card lays its
  values in two columns, with the actions on a line of their own, so a card is half as tall as the
  phone's one column; on a phone (640px and below) it stays one column.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.TranslatedDsl

  @admin %{id: "user-1", role: :admin}
  @records [%{id: "row-1", title: "Plain", slug: "plain", status: :published, featured: false}]

  defp render_table do
    state =
      "tablet-cards"
      |> State.init(TranslatedDsl, @admin)
      |> State.update(loading: :loaded, has_initial_data?: true)

    stream_name = state.static.stream_name

    render_component(&TableTemplate.render/1, %{
      static: state.static,
      state: state,
      stream: Enum.map(@records, &{"#{stream_name}-#{&1.id}", &1}),
      streams: %{stream_name => []},
      empty?: false,
      failed?: false,
      myself: nil,
      __changed__: %{}
    })
    |> LazyHTML.from_fragment()
  end

  defp classes(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute("class") |> Enum.join(" ")

  test "a row is a two-column card on a tablet and a one-column card on a phone" do
    doc = render_table()
    row = classes(doc, ".gervaz-row")

    assert row =~ "min-[641px]:max-[980px]:grid!"
    assert row =~ "min-[641px]:max-[980px]:grid-cols-2"
    assert row =~ "max-[640px]:flex!"
    assert row =~ "max-[640px]:flex-col!"
    refute row =~ "max-[980px]:flex!"
  end

  test "the actions of a card take a line of their own on a tablet" do
    doc = render_table()

    assert classes(doc, "[data-role=gervaz-row-actions]") =~
             "min-[641px]:max-[980px]:col-span-full"
  end
end

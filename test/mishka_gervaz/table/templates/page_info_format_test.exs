defmodule MishkaGervaz.Table.Templates.PageInfoFormatTest do
  @moduledoc """
  `page_info_format` fills `{page}`, `{total}` and `{count}`, and prints any other placeholder as
  written.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Shared
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.NumberedScrollResource

  defp render_footer(format) do
    state =
      "posts"
      |> State.init(NumberedScrollResource, nil)
      |> State.update(
        loading: :loaded,
        has_initial_data?: true,
        page: 2,
        total_pages: 3,
        total_count: 50
      )

    ui = %{state.static.pagination_ui | page_info_format: format}
    static = %{state.static | pagination_ui: ui}

    render_component(&Shared.render_pagination/1, %{
      static: static,
      state: state,
      myself: nil,
      __changed__: %{}
    })
  end

  test "fills {page}, {total} and {count}" do
    assert render_footer("Page {page} of {total}, {count} rows") =~
             "Page 2 of 3, 50 rows"
  end

  test "prints {from} and {to} as written" do
    assert render_footer("{from} to {to} of {count}") =~ "{from} to {to} of 50"
  end
end

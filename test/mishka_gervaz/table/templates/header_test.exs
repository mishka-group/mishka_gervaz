defmodule MishkaGervaz.Table.Templates.HeaderTest do
  @moduledoc """
  The table header: every cell shares one type, and a label too long for its column is cut short
  inside it rather than running under the next header.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.Post

  @type_classes "px-[16px] text-[11px] font-bold tracking-[0.03em] text-[#8a877f]"

  # The header alone, from its opening tag to the first row container after it.
  defp header do
    state =
      "header-test"
      |> State.init(Post, nil)
      |> State.update(loading: :loaded, has_initial_data?: true)

    stream_name = state.static.stream_name

    html =
      render_component(&TableTemplate.render/1, %{
        static: state.static,
        state: state,
        stream: [],
        streams: %{stream_name => []},
        empty?: false,
        myself: nil,
        __changed__: %{}
      })

    [_before, thead] = String.split(html, ~s(id="#{stream_name}-thead"), parts: 2)
    thead
  end

  test "the Actions cell wears the same type as every column header" do
    thead = header()

    assert thead =~ ~s(<div class="text-right #{@type_classes}">)
    refute thead =~ "text-sm font-medium"
  end

  test "a sortable header cell can shrink below its label's width" do
    assert header() =~ ~s(class="min-w-0 text-left #{@type_classes} cursor-pointer")
  end

  test "a label is cut short inside its column, and its sort badge never is" do
    thead = header()

    assert thead =~ ~s(<div class="flex min-w-0 items-center gap-1">)
    assert thead =~ ~s(<span class="truncate">)
    assert thead =~ ~s(<span class="ml-1 inline-flex shrink-0 items-center">)
  end
end

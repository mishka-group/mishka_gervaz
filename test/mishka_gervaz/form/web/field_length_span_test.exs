defmodule MishkaGervaz.Form.Web.FieldLengthSpanTest do
  @moduledoc """
  What a field's input carries for the browser: a text field stops at the `max_length` of its
  attribute (or the field's own `max_length`), and a field that spans two columns takes the whole
  row on a phone, where the grid has one column, so it never makes a second, implicit one.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{Live, Renderer}
  alias MishkaGervaz.Test.Resources.LengthEntry

  defp html do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        %{id: "length-entry", resource: LengthEntry, current_user: %{id: "u", site_id: nil}},
        socket
      )

    drawn = render_component(&Renderer.render/1, %{form_state: socket.assigns.form_state})
    LazyHTML.from_fragment(drawn)
  end

  defp attr(html, selector, name),
    do: html |> LazyHTML.query(selector) |> LazyHTML.attribute(name) |> List.first()

  test "a text field takes its attribute's max_length, and a field's own max_length wins" do
    html = html()

    assert attr(html, ~s(input[name="form[title]"]), "maxlength") == "120"
    assert attr(html, ~s(input[name="form[code]"]), "maxlength") == "8"
    assert attr(html, ~s(textarea[name="form[summary]"]), "maxlength") == nil
  end

  test "a field of two columns is the whole row below the breakpoint and two columns from it" do
    classes = html() |> LazyHTML.query("div.col-span-full") |> LazyHTML.attribute("class")

    assert Enum.any?(classes, &(&1 =~ "md:col-span-2"))
    refute Enum.any?(classes, &(&1 |> String.split() |> Enum.member?("col-span-2")))
  end
end

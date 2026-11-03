defmodule MishkaGervaz.Table.Web.TemplateUrlLiveTest do
  @moduledoc """
  The template a reader picks, kept in the URL by a table with `:template` in its `url_sync`
  params, driven the way a reader drives it.

  The switcher writes the template it opens to the URL as its name, and a URL that names one the
  table offers opens the table in it, so a reload or a shared link shows the same view. A URL that
  names a template the table does not offer opens the table's own.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.KeptItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000

  setup do
    on_exit(fn -> KeptItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    for title <- ["Alpha", "Beta", "Gamma"], do: Ash.create!(KeptItem, %{title: title})
    :ok
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view, @await)
    view
  end

  defp kept_rows?(view), do: has_element?(view, ~s|#items[data-template="kept_rows"]|)

  defp switch(view, template) do
    view
    |> element(~s|#items [phx-click="switch_template"][phx-value-template="#{template}"]|)
    |> render_click()

    render_async(view, @await)
  end

  test "a URL naming a template the table offers opens the table in it" do
    assert open("/kept?template=kept_rows") |> kept_rows?()
    refute open("/kept") |> kept_rows?()
  end

  test "switching writes the template's name to the URL, and that URL opens it again" do
    view = open("/kept")

    switch(view, "kept_rows")

    assert kept_rows?(view)
    assert_patch(view, "/kept?template=kept_rows")
    assert open("/kept?template=kept_rows") |> kept_rows?()

    switch(view, "table")

    refute kept_rows?(view)
    assert_patch(view, "/kept?template=table")
  end

  test "going back to the URL of the template shown before shows it again" do
    view = open("/kept?template=table")

    switch(view, "kept_rows")
    assert_patch(view, "/kept?template=kept_rows")

    render_patch(view, "/kept?template=table")
    render_async(view, @await)

    refute kept_rows?(view)
  end

  test "a URL naming a template the table does not offer opens the table's own" do
    refute open("/kept?template=media_gallery") |> kept_rows?()
    refute open("/kept?template=no_such_template") |> kept_rows?()
  end
end

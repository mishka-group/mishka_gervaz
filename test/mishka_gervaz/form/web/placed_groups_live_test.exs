defmodule MishkaGervaz.Form.Web.PlacedGroupsLiveTest do
  @moduledoc """
  A page that places a form's groups in its own cards with the `:body` slot and
  `MishkaGervaz.Form.Web.Live.group/1` (`MishkaGervaz.Test.Web.PlacedPageLive`), driven the way an
  admin drives it.

  It proves the groups land in the page's cards with the page's own card between them, that a
  field drawn only while a toggle is on follows it, that a field's error shows in the card of its
  group, that one submit saves the fields of both cards, that the unsaved changes and Discard work
  as they do without the slot, that the page's own button in the slot reaches the page, and that the
  cards are drawn while the form loads.

  It does NOT prove how the cards look, or a `:wizard` or `:tabs` form, which ignore the slot.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Web.{Live, State}
  alias MishkaGervaz.Test.Web.PlacedItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#placed-form"

  setup do
    on_exit(fn -> PlacedItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path \\ "/placed") do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp change(view, values),
    do: view |> form(@form, %{"form" => values}) |> render_change()

  test "each group is drawn in its own card, with the page's card between them, in one form" do
    view = open()

    assert has_element?(view, ~s|#{@form} #card-basics [name="form[title]"]|)
    assert has_element?(view, ~s|#{@form} #card-keys [name="form[licensed]"]|)
    refute has_element?(view, ~s|#card-keys [name="form[title]"]|)
    refute has_element?(view, ~s|#card-basics [name="form[licensed]"]|)
    assert has_element?(view, "#{@form} #card-between")
    assert has_element?(view, "#card-keys", "A key is sent with the receipt")
    refute has_element?(view, "#card-basics", "A key is sent with the receipt")
  end

  test "a field in no group is drawn after the cards, still in the form" do
    view = open()

    assert has_element?(view, ~s|#{@form} [name="form[note]"]|)
    refute has_element?(view, ~s|#card-basics [name="form[note]"]|)
    refute has_element?(view, ~s|#card-keys [name="form[note]"]|)
  end

  test "a field drawn only while the toggle is on follows it" do
    view = open()
    refute has_element?(view, ~s|[name="form[places]"]|)

    change(view, %{"title" => "Kit", "licensed" => "true"})
    assert has_element?(view, ~s|#card-keys [name="form[places]"]|)

    change(view, %{"title" => "Kit", "licensed" => "false"})
    refute has_element?(view, ~s|[name="form[places]"]|)
  end

  test "an error of the second group's field shows in the second card" do
    view = open()
    change(view, %{"title" => "Kit", "licensed" => "true"})

    view
    |> form(@form, %{"form" => %{"title" => "Kit", "licensed" => "true", "places" => "50"}})
    |> render_submit()

    assert has_element?(view, "#card-keys", "less than or equal to 10")
    refute has_element?(view, "#card-basics", "less than or equal to 10")
    assert Ash.read!(PlacedItem) == []
  end

  test "one submit saves the fields of both cards" do
    view = open()
    change(view, %{"title" => "Kit", "licensed" => "true"})

    view
    |> form(@form, %{"form" => %{"title" => "Kit", "licensed" => "true", "places" => "4"}})
    |> render_submit()

    assert [%{title: "Kit", licensed: true, places: 4}] = Ash.read!(PlacedItem)
    assert has_element?(view, "#saved", "Kit")
  end

  test "an edit keeps a hidden field's saved value" do
    item = Ash.create!(PlacedItem, %{title: "Kit", licensed: true, places: 7})
    view = open("/placed?id=#{item.id}")

    assert has_element?(view, ~s|#card-keys [name="form[places]"][value="7"]|)

    view
    |> form(@form, %{"form" => %{"title" => "Kit 2", "licensed" => "false"}})
    |> render_submit()

    assert %{title: "Kit 2", licensed: false, places: 7} = Ash.get!(PlacedItem, item.id)
  end

  test "the unsaved changes and Discard work as without the slot" do
    item = Ash.create!(PlacedItem, %{title: "Kit"})
    view = open("/placed?id=#{item.id}")
    assert has_element?(view, "#dirty", "false")

    change(view, %{"title" => "Changed"})
    assert has_element?(view, "#dirty", "true")

    view |> element(~s|#{@form} [data-role="gervaz-discard"]|) |> render_click()
    render_async(view)

    assert has_element?(view, "#dirty", "false")
    assert has_element?(view, ~s|#card-basics [name="form[title]"][value="Kit"]|)
  end

  test "the page's own button in the slot reaches the page" do
    view = open()

    view |> element("#card-between button") |> render_click()

    assert has_element?(view, "#presses", "1")
  end

  test "the cards are drawn while the form loads, each group showing that it loads" do
    html = build_conn() |> get("/placed") |> html_response(200)
    doc = LazyHTML.from_document(html)

    assert LazyHTML.query(doc, "#card-between") |> Enum.count() == 1

    assert LazyHTML.query(doc, "#card-basics [data-role=gervaz-form-loading]") |> Enum.count() ==
             1

    assert LazyHTML.query(doc, "#card-keys [data-role=gervaz-form-loading]") |> Enum.count() == 1
    assert LazyHTML.query(doc, "form") |> Enum.count() == 0
  end

  test "a group the form does not have is refused by name" do
    state = State.init("placed", PlacedItem, %{id: "m", site_id: nil, role: :admin})
    form = %{__changed__: nil, static: state.static, state: state, myself: nil, uploads: %{}}

    assert_raise ArgumentError, ~r/has no group :missing/, fn ->
      Live.group(%{__changed__: nil, form: form, name: :missing})
    end
  end
end

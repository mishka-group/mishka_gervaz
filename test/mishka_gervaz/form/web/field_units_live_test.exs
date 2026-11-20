defmodule MishkaGervaz.Form.Web.FieldUnitsLiveTest do
  @moduledoc """
  A field's `ui` `prefix` and `suffix` on a form, a LiveComponent on a page, driven the way an admin
  drives it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`).

  The unit stands joined to the input, at its start or its end, and names it for a screen reader
  through `aria-describedby`. It is only shown: what is typed is saved without it.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/plans")
    render_async(view)
    view
  end

  defp described_by(view, name) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{@form} input[name="form[#{name}]"]|)
    |> LazyHTML.attribute("aria-describedby")
  end

  test "a text field draws its prefix before the input" do
    view = open()
    units = ~s|#{@form} [data-role="gervaz-input-units"]|

    assert has_element?(view, ~s|#{units} [data-role="gervaz-input-prefix"]|, "/products/")
    assert has_element?(view, ~s|#{units} input[name="form[slug]"].rounded-s-none|)
    assert [id] = described_by(view, "slug")
    assert has_element?(view, ~s|##{id}|, "/products/")
  end

  test "a number field draws its prefix, and a suffix given as a function" do
    view = open()

    assert has_element?(view, ~s|#{@form} [data-role="gervaz-input-prefix"]|, "USD")
    assert has_element?(view, ~s|#{@form} [data-role="gervaz-input-suffix"]|, "%")

    assert has_element?(
             view,
             ~s|#{@form} input[type="number"][name="form[discount]"].rounded-e-none|
           )

    assert [id] = described_by(view, "discount")
    assert has_element?(view, ~s|##{id}|, "%")
  end

  test "a field without units draws its input alone" do
    view = open()

    refute has_element?(
             view,
             ~s|#{@form} [data-role="gervaz-input-units"] input[name="form[title]"]|
           )

    assert described_by(view, "title") == []
  end

  test "what is typed is saved without the units" do
    view = open()

    view
    |> form(@form, %{
      "form" => %{"title" => "Kit", "slug" => "kit", "price" => "19.90", "discount" => "15"}
    })
    |> render_submit()

    assert [%{slug: "kit", discount: 15, price: price}] = Ash.read!(PlanItem)
    assert Decimal.equal?(price, Decimal.new("19.90"))
  end
end

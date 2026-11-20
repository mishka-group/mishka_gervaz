defmodule MishkaGervaz.Form.Web.DecimalBoundsLiveTest do
  @moduledoc """
  A `:number` field bounded by `Decimal`s, on a form, a LiveComponent on a page, driven the way an
  admin drives it (`MishkaGervaz.Test.Web.PlanItem` on `MishkaGervaz.Test.Web.PlanPageLive`): its
  `:price` runs from `Decimal.new("0.50")` to `fn -> Decimal.new("9999.99") end`.

  The input carries both bounds as plain digits. A save of a value outside them shows "is too
  small" or "is too large" and saves nothing; the bounds themselves are allowed. `Number.validate/2`,
  which also checks a value while it is typed, compares as `Decimal`s.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Types.Field.Number
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

  defp save(view, price) do
    view
    |> form(@form, %{"form" => %{"title" => "Kit", "price" => price}})
    |> render_submit()
  end

  test "the input carries the bounds as plain digits" do
    view = open()

    assert has_element?(
             view,
             ~s|#{@form} input[name="form[price]"][min="0.50"][max="9999.99"][step="0.01"]|
           )
  end

  test "a price under the minimum is refused on save" do
    view = open()
    save(view, "0.49")

    assert render(view) =~ "is too small"
    assert Ash.read!(PlanItem) == []
  end

  test "a price over the maximum is refused on save" do
    view = open()
    save(view, "10000")

    assert render(view) =~ "is too large"
    assert Ash.read!(PlanItem) == []
  end

  test "the bounds themselves are saved" do
    view = open()
    save(view, "0.5")

    assert [%{price: price}] = Ash.read!(PlanItem)
    assert Decimal.equal?(price, Decimal.new("0.50"))
  end

  describe "Number.validate/2" do
    @bounds %{min: Decimal.new("0.50"), max: Decimal.new("9999.99")}

    test "compares a typed value, a float and a Decimal with Decimal bounds" do
      assert {:ok, "0.50"} = Number.validate("0.50", @bounds)
      assert {:error, _} = Number.validate("0.4999", @bounds)
      assert {:ok, 9999.99} = Number.validate(9999.99, @bounds)
      assert {:error, _} = Number.validate(Decimal.new("10000"), @bounds)
      assert {:ok, 3} = Number.validate(3, @bounds)
    end

    test "keeps integer and float bounds working" do
      assert {:error, _} = Number.validate("11", %{min: 0, max: 10})
      assert {:ok, "2.5"} = Number.validate("2.5", %{min: 0.5, max: 2.5})
      assert {:error, _} = Number.validate("2.51", %{min: 0.5, max: 2.5})
    end
  end
end

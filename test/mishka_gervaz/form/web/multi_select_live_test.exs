defmodule MishkaGervaz.Form.Web.MultiSelectLiveTest do
  @moduledoc """
  A `:multi_select` over an `{:array, :atom}` attribute on a form, a LiveComponent on a page, driven
  the way an admin drives it (`MishkaGervaz.Test.Web.PlanItem` on
  `MishkaGervaz.Test.Web.PlanPageLive`).

  It draws one checkbox per option, all named `form[channels][]`, an option's second line under its
  label. A save stores the ticked values as a list, and an empty list once none is ticked.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.PlanItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#plan-form"
  @boxes ~s|#plan-form [data-role="gervaz-multi-select"]|

  setup do
    on_exit(fn -> PlanItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open(path \\ "/plans") do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp ticked(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|#{@boxes} input[type="checkbox"][checked]|)
    |> LazyHTML.attribute("value")
  end

  defp save(view, channels) do
    view
    |> form(@form, %{"form" => %{"title" => "Kit", "channels" => channels}})
    |> render_submit()
  end

  test "draws a named checkbox per option, a second line under the labels that have one" do
    view = open()

    assert has_element?(
             view,
             ~s|#{@boxes} input[type="hidden"][name="form[channels][]"][value=""]|
           )

    for value <- ~w(store email feed) do
      assert has_element?(
               view,
               ~s|#{@boxes} input[type="checkbox"][name="form[channels][]"][value="#{value}"]|
             )
    end

    assert has_element?(
             view,
             ~s|#{@boxes} label:has(input[value="store"]) [data-role="gervaz-checkbox-description"]|,
             "The public store page"
           )

    refute has_element?(
             view,
             ~s|#{@boxes} label:has(input[value="feed"]) [data-role="gervaz-checkbox-description"]|
           )
  end

  test "a change keeps what was ticked" do
    view = open()

    view |> form(@form, %{"form" => %{"channels" => ["", "email", "feed"]}}) |> render_change()

    assert ticked(view) == ["email", "feed"]
  end

  test "a save stores the ticked values as a list" do
    view = open()
    save(view, ["", "store", "feed"])

    assert [%{channels: [:store, :feed]}] = Ash.read!(PlanItem)
  end

  test "a save with none ticked stores an empty list" do
    plan = Ash.create!(PlanItem, %{title: "Kit", channels: [:email]})
    view = open("/plans?id=#{plan.id}")
    assert ticked(view) == ["email"]

    save(view, [""])

    assert [%{channels: []}] = Ash.read!(PlanItem)
  end
end

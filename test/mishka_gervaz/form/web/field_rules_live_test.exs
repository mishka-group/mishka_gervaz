defmodule MishkaGervaz.Form.Web.FieldRulesLiveTest do
  @moduledoc """
  What a form says when a person breaks a field's rule, on the form of
  `MishkaGervaz.Test.Web.RuleItem` on `MishkaGervaz.Test.Web.RulePageLive`, driven the way an admin
  drives it.

  Each message under a field names the field, so it reads alone as a sentence.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.RuleItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#rule-form"

  setup do
    on_exit(fn -> RuleItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/rules")
    render_async(view)
    view
  end

  defp save(view, values) do
    view
    |> form(@form, %{"form" => values})
    |> render_submit()

    view
  end

  # The messages shown under the fields, as a person reads them.
  defp field_errors(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("p[class*='c0392b']")
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  describe "a required field left empty" do
    test "is named in its message" do
      errors = open() |> save(%{"name" => "", "seats" => ""}) |> field_errors()

      assert "Name is required" in errors
      assert "Seats is required" in errors
      refute "is required" in errors
      assert Ash.read!(RuleItem) == []
    end

    test "a sub-field of a list of maps is named by its own label" do
      view = open()

      view |> element(~s|#{@form} button[phx-value-field="contacts"]|) |> render_click()

      save(view, %{
        "name" => "Ann",
        "seats" => "2",
        "contacts" => %{"0" => %{"person" => "", "phone" => "555"}}
      })

      errors = field_errors(view)
      assert "Person is required" in errors
      refute "is required" in errors
    end
  end

  describe "a number past its bound" do
    test "the action's own sentence is the one message under the field" do
      errors =
        open() |> save(%{"name" => "Ann", "seats" => "2", "budget" => "150"}) |> field_errors()

      assert errors == ["Use 100 or less: that is the budget."]
      assert Ash.read!(RuleItem) == []
    end
  end
end

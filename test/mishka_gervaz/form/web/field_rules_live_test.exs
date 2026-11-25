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
    test "the field takes the bounds of its attribute's constraints" do
      assert has_element?(open(), ~s|#{@form} input[name="form[seats]"][inputmode="decimal"]|)

      errors = open() |> save(%{"name" => "Ann", "seats" => "0"}) |> field_errors()
      assert errors == ["Seats must be 1 or more"]
    end

    test "the bound of its attribute is named in one sentence" do
      errors = open() |> save(%{"name" => "Ann", "seats" => "11"}) |> field_errors()

      assert errors == ["Seats must be 10 or less"]
      assert Ash.read!(RuleItem) == []
    end

    test "the action's own sentence is the one message under the field" do
      errors =
        open() |> save(%{"name" => "Ann", "seats" => "2", "budget" => "150"}) |> field_errors()

      assert errors == ["Use 100 or less: that is the budget."]
      assert Ash.read!(RuleItem) == []
    end
  end

  describe "a text field given HTML tags" do
    test "keeps them as typed while the form checks it" do
      view = open()

      view |> form(@form, %{"form" => %{"name" => "<b>Ann</b>"}}) |> render_change()

      assert has_element?(view, ~s|#{@form} input[name="form[name]"][value="<b>Ann</b>"]|)
    end

    test "is refused on save in words, and the field keeps what was typed" do
      view = open() |> save(%{"name" => "<script>alert(1)</script>Ann", "seats" => "2"})

      assert "Name must be plain text, without HTML tags" in field_errors(view)

      assert has_element?(
               view,
               ~s|#{@form} input[name="form[name]"][value="<script>alert(1)</script>Ann"]|
             )

      assert Ash.read!(RuleItem) == []
    end

    test "a bare < or > is text and is saved" do
      open() |> save(%{"name" => "a < b > c", "seats" => "2"})

      assert [%{name: "a < b > c"}] = Ash.read!(RuleItem)
    end
  end

  describe "a value longer than the field's max_length" do
    test "the input carries the limit" do
      view = open()

      assert has_element?(view, ~s|#{@form} input[name="form[name]"][maxlength="20"]|)
      assert has_element?(view, ~s|#{@form} textarea[name="form[note]"][maxlength="40"]|)
    end

    test "that still reaches the form is refused in one sentence that names the limit" do
      view =
        open()
        |> save(%{
          "name" => String.duplicate("a", 25),
          "note" => String.duplicate("b", 50),
          "seats" => "2"
        })

      errors = field_errors(view)

      assert "Name must be 20 characters or fewer" in errors
      assert "Note must be 40 characters or fewer" in errors
      refute Enum.any?(errors, &(&1 =~ "less than or equal to"))
      assert Ash.read!(RuleItem) == []
    end
  end

  describe "the inputs" do
    test "a required field's input carries required, and the others do not" do
      view = open()

      assert has_element?(view, ~s|#{@form} input[name="form[name]"][required]|)
      assert has_element?(view, ~s|#{@form} input[name="form[seats]"][required]|)
      refute has_element?(view, ~s|#{@form} textarea[name="form[note]"][required]|)
      refute has_element?(view, ~s|#{@form} input[name="form[budget]"][required]|)
    end

    test "the form leaves every message to itself, so the browser never stops a save" do
      assert has_element?(open(), "form#{@form}[novalidate]")
    end
  end
end

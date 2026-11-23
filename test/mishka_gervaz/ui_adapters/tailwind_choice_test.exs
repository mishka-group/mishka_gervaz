defmodule MishkaGervaz.UIAdapters.TailwindChoiceTest do
  @moduledoc """
  The default adapter's two choice controls, `choice_cards/1` and `segmented_control/1`: a radio
  per option in a `radiogroup`, the value given checked, every radio off when the field is, and one
  radio off when its option is.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.Helpers
  alias MishkaGervaz.UIAdapters.Tailwind

  @options Helpers.choice_options([
             {"Monthly", :monthly},
             [label: "Yearly", value: :yearly, description: "Two months free", icon: "hero-star"]
           ])

  defp render(fun, assigns) do
    %{__changed__: nil, name: "form[billing]", id: "f-billing", options: @options}
    |> Map.merge(assigns)
    |> then(&apply(Tailwind, fun, [&1]))
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  defp radios(doc), do: LazyHTML.query(doc, ~s|input[type="radio"][name="form[billing]"]|)

  for fun <- [:choice_cards, :segmented_control] do
    describe "#{fun}" do
      test "draws a radio per option with the option's value and id" do
        doc = render(unquote(fun), %{value: "yearly"})

        assert LazyHTML.attribute(radios(doc), "value") == ["monthly", "yearly"]
        assert LazyHTML.attribute(radios(doc), "id") == ["f-billing-0", "f-billing-1"]
        assert LazyHTML.query(doc, ~s|[role="radiogroup"]|) |> Enum.count() == 1
      end

      test "lays the radio unseen over its whole option, so the option is what is pressed" do
        doc = render(unquote(fun), %{value: "yearly"})

        for class <- LazyHTML.attribute(radios(doc), "class") do
          assert class =~ "absolute inset-0"
          assert class =~ "size-full"
          assert class =~ "opacity-0"
        end

        for class <- doc |> LazyHTML.query("label[data-value]") |> LazyHTML.attribute("class"),
            do: assert(class =~ "relative")
      end

      test "checks the value given and no other" do
        doc = render(unquote(fun), %{value: "yearly"})

        assert doc |> LazyHTML.query(~s|input[checked]|) |> LazyHTML.attribute("value") == [
                 "yearly"
               ]
      end

      test "draws the second line and icon of the option that has them" do
        doc = render(unquote(fun), %{value: nil})

        assert doc
               |> LazyHTML.query(
                 ~s|[data-value="yearly"] [data-role="gervaz-choice-description"]|
               )
               |> LazyHTML.text() =~ "Two months free"

        assert doc |> LazyHTML.query(~s|[data-value="yearly"] .hero-star|) |> Enum.count() == 1

        assert doc
               |> LazyHTML.query(
                 ~s|[data-value="monthly"] [data-role="gervaz-choice-description"]|
               )
               |> Enum.count() == 0
      end

      test "switches every radio off when disabled" do
        doc = render(unquote(fun), %{value: "monthly", disabled: true})

        assert doc |> radios() |> LazyHTML.attribute("disabled") |> length() == 2
      end

      test "switches off only an option marked disabled, still drawn with its label" do
        options =
          Helpers.choice_options([
            {"Monthly", :monthly},
            [label: "Yearly", value: :yearly, disabled: true]
          ])

        doc = render(unquote(fun), %{value: nil, options: options})

        assert doc |> LazyHTML.query(~s|input[disabled]|) |> LazyHTML.attribute("value") == [
                 "yearly"
               ]

        assert doc |> LazyHTML.query(~s|[data-value="yearly"]|) |> LazyHTML.text() =~ "Yearly"
      end
    end
  end

  describe "toggle_input" do
    test "lays the switch's checkbox over its whole label, 44 px tall on a touch screen" do
      doc =
        %{__changed__: nil, name: "form[listed]", id: "f-listed", checked: true, note: "Listed"}
        |> Tailwind.toggle_input()
        |> rendered_to_string()
        |> LazyHTML.from_fragment()

      [class] = doc |> LazyHTML.query(~s|input[role="switch"]|) |> LazyHTML.attribute("class")
      assert class =~ "absolute inset-0"
      assert class =~ "opacity-0"

      [label] = doc |> LazyHTML.query("label") |> LazyHTML.attribute("class")
      assert label =~ "relative"
      assert label =~ "pointer-coarse:min-h-11"
    end
  end
end

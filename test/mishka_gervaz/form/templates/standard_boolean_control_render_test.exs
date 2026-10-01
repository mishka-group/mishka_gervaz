defmodule MishkaGervaz.Form.Templates.StandardBooleanControlRenderTest do
  @moduledoc """
  A checkbox or a toggle stands in a 44px box, the height of the inputs beside it, so its centre
  lines up with theirs in the same grid row. Every place a form draws one gets the box: a field, a
  nested sub-field and a key of a key map.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.{ConstrainedMapForm, FormPost, NestedForm}

  @box ~s(<div data-role="gervaz-boolean-control" class="flex h-11 items-center">)

  defp render_form(fields) do
    state =
      build_state(
        static_opts: [fields: fields, groups: []],
        mode: :create,
        form: to_form(%{}, as: :form)
      )

    static = %{state.static | notices: []}
    state = %{state | static: static}

    render_component(&Standard.render/1, %{
      static: static,
      state: state,
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  # Everything inside the first box, up to the box's own closing tag.
  defp boxed(html) do
    [_, inside] = String.split(html, @box, parts: 2)
    [control | _] = String.split(inside, ~r/<\/label>\s*<\/div>/, parts: 2)
    control
  end

  defp featured(type), do: %{FormInfo.field(FormPost, :featured) | type: type}

  defp sub_field(type) do
    Map.update!(FormInfo.field(NestedForm, :tags), :nested_fields, fn [first | rest] ->
      [%{first | type: type} | rest]
    end)
  end

  describe "a field" do
    test "draws its checkbox in the box" do
      control = render_form([featured(:checkbox)]) |> boxed()

      assert control =~ ~s(type="checkbox")
      assert control =~ ~s(name="form[featured]")
    end

    test "draws its toggle in the box" do
      control = render_form([featured(:toggle)]) |> boxed()

      assert control =~ ~s(role="switch")
      assert control =~ ~s(name="form[featured]")
    end

    test "keeps its label above the box and its help text below it" do
      field = featured(:checkbox)
      field = %{field | ui: %{field.ui | description: "Shown first"}}
      html = render_form([field])

      [before_box, after_box] = String.split(html, @box, parts: 2)

      assert before_box =~ ~r/<label[^>]*>\s*Featured/
      assert after_box =~ "gervaz-field-description"
      refute before_box =~ "gervaz-field-description"
    end

    test "draws any other control without the box" do
      for name <- [:title, :content, :status, :priority] do
        refute render_form([FormInfo.field(FormPost, name)]) =~ "gervaz-boolean-control",
               "#{name} was boxed"
      end
    end
  end

  describe "a nested sub-field" do
    test "draws its checkbox and its toggle in the box" do
      assert render_form([sub_field(:checkbox)]) |> boxed() =~ ~s(type="checkbox")
      assert render_form([sub_field(:toggle)]) |> boxed() =~ ~s(role="switch")
    end

    test "draws a text input without the box" do
      refute render_form([sub_field(:text)]) =~ "gervaz-boolean-control"
    end
  end

  describe "a key of a key map" do
    test "draws its toggle in the box and its text input without one" do
      html = render_form([FormInfo.field(ConstrainedMapForm, :settings)])

      assert boxed(html) =~ ~s(name="form[settings][compact]")
      assert length(Regex.scan(~r/gervaz-boolean-control/, html)) == 1
    end
  end
end

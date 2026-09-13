defmodule MishkaGervaz.Form.Templates.StandardDescriptionRenderTest do
  @moduledoc """
  A field's own help text, which the DSL has declared and nothing has ever drawn.

  `ui do description "…" end` has been in the field schema — typed, documented as "Help text below
  the field" — since before this test existed, and `MishkaGervaz.Form.Templates.Standard` never
  passed it to the UI adapter. A resource could write one, have it compile, have it appear in the
  generated docs, and no reader would ever see the text. The two `@description` assigns the Tailwind
  adapter did read belong to `field_group/1`'s fieldset legend and `form_header/1`'s subtitle,
  neither of which is a field.

  `MishkaGervaz.Test.Resources.FormPost`'s `:title` has carried `description "Main title"` the whole
  time, which is how long it went unnoticed.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost

  @help "gervaz-field-description"

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

  # The compiled `ui` is a plain map rather than a `%Field.Ui{}` — the transformer flattens it — so
  # this updates a map rather than a struct.
  defp described(field, description),
    do: %{field | ui: %{field.ui | description: description}}

  describe "a field's help text" do
    test "is drawn under the input", %{} do
      html = render_form([FormInfo.field(FormPost, :title)])

      assert html =~ "Main title",
             "the description the resource declared never reached the reader"

      assert html =~ @help
    end

    # AFTER THE INPUT, not before it. The DSL calls it "Help text below the field" and that is where
    # a reader looks for a footnote; putting it above pushes the label away from the control it
    # names.
    test "comes after the control it belongs to" do
      html = render_form([FormInfo.field(FormPost, :title)])

      assert String.contains?(html, "Main title")

      [before_help, _after] = String.split(html, @help, parts: 2)

      assert before_help =~ ~s|name="form[title]"|,
             "the help text was drawn before the input it describes"
    end

    # A FORM WHOSE LABELS ARE TRANSLATED AND WHOSE HELP TEXT IS NOT is the trap: `label` and
    # `placeholder` have always taken `fn -> gettext(…) end` and `description` was typed as a plain
    # string, so the one line explaining the field was the one line stuck in English.
    test "can be a function, the way a label and a placeholder can" do
      field = described(FormInfo.field(FormPost, :title), fn -> "resolved at render" end)

      assert render_form([field]) =~ "resolved at render"
    end

    test "is absent when the field declares none" do
      html = render_form([FormInfo.field(FormPost, :content)])

      refute html =~ @help
    end

    # IT IS PASSED AT THE WRAPPER, so it is not a per-type feature that some controls have and others
    # do not. A select and a checkbox reach `field_wrapper/1` by the same path a text input does.
    test "reaches every kind of control, not only a text input" do
      for name <- [:content, :status, :priority, :featured] do
        field = described(FormInfo.field(FormPost, name), "help for #{name}")

        assert render_form([field]) =~ "help for #{name}",
               "#{name} (#{inspect(FormInfo.field(FormPost, name).type)}) drew no help text"
      end
    end
  end
end

defmodule MishkaGervaz.Form.Templates.StandardNestedRenderTest do
  @moduledoc """
  Nested sub-fields have to actually RENDER, which nothing asked before.

  Every other test of this path checks the field's shape after transformation — is it `:nested`,
  does it have four sub-fields, is `nested_source` right. All of those passed while the template
  raised on the first sub-field it tried to draw, because `sub_field_input/1` builds its assigns as
  a bare map and `Phoenix.Component.assign/3` refuses anything that is not a socket or a real
  assigns map:

      ** (ArgumentError) assign/3 expects a socket from Phoenix.LiveView/Phoenix.LiveComponent
         or an assigns map from Phoenix.Component as first argument, got: %{disabled: false, …}

  In the browser that is a LiveView crash, which looks to a reader like the page reloading itself
  when they press "Add event".

  So this renders the template for real, one case per sub-field type, because each type is its own
  clause of `sub_field_input/1` and a fix that only reaches the one somebody happened to try is
  worth very little.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ConstrainedMapForm
  alias MishkaGervaz.Test.Resources.NestedForm

  # `render_component/2` wants a function component; the template is one, and rendering it is the
  # whole point — the crash lives between the field's shape and the HTML.
  defp render_form(field, form \\ nil) do
    state =
      build_state(
        static_opts: [fields: [field], groups: []],
        mode: :create,
        form: form || to_form(%{}, as: :form)
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

  describe "a nested field draws its sub-fields" do
    test "an embedded array renders without raising" do
      html = render_form(FormInfo.field(NestedForm, :items))

      assert is_binary(html)
      assert html != ""
    end

    test "a map-based nested field renders without raising" do
      html = render_form(FormInfo.field(NestedForm, :tags))

      assert is_binary(html)
      assert html != ""
    end
  end

  # A CLASS IS AN ADDITION, NOT A SWAP. Six resources in this project write
  # `class "font-mono text-sm"` on a code sub-field; none of them means "and drop the border".
  describe "a sub-field's own class" do
    test "is added to the adapter's, not swapped for it" do
      base = FormInfo.field(NestedForm, :tags)

      field =
        Map.update!(base, :nested_fields, fn [first | rest] ->
          [first |> Map.put(:type, :text) |> Map.put(:class, "font-mono") | rest]
        end)

      html = render_form(field)

      assert html =~ "font-mono"
      assert html =~ "rounded-[11px]", "the adapter's own styling has to survive"
    end

    test "a textarea keeps the adapter's multiline styling too" do
      base = FormInfo.field(NestedForm, :tags)

      field =
        Map.update!(base, :nested_fields, fn [first | rest] ->
          [first |> Map.put(:type, :textarea) |> Map.put(:class, "font-mono") | rest]
        end)

      html = render_form(field)

      assert html =~ "font-mono"
      assert html =~ "rounded-[11px]"
    end

    test "no class named leaves the adapter's default alone" do
      base = FormInfo.field(NestedForm, :tags)

      field =
        Map.update!(base, :nested_fields, fn [first | rest] ->
          [first |> Map.put(:type, :text) |> Map.put(:class, nil) | rest]
        end)

      assert render_form(field) =~ "rounded-[11px]"
    end
  end

  # ONE CLAUSE PER TYPE, so a fix that only reaches `:text` cannot pass for a fix.
  describe "every sub-field type its own clause draws" do
    setup do
      %{base: FormInfo.field(NestedForm, :tags)}
    end

    for type <- [
          :text,
          :textarea,
          :number,
          :select,
          :checkbox,
          :toggle,
          :date,
          :datetime,
          :range,
          :json,
          :key_map,
          :key_list
        ] do
      test "#{type}", %{base: base} do
        type = unquote(type)

        field =
          Map.update!(base, :nested_fields, fn [first | rest] ->
            [%{first | type: type} | rest]
          end)

        assert is_binary(render_form(field))
      end
    end
  end

  # THE SAME MISTAKE, ONE LEVEL DOWN. A `:key_map` draws one control per declared key, and each of
  # those controls was being called as a plain function with a bare map for assigns — which is the
  # exact crash this file was written about, made again inside the clause that draws them. The type
  # was also missing from the list above, which is how it got through.
  describe "a key map draws a control for each key it declares" do
    setup do
      keys = [
        [name: :required, type: :toggle, label: "Required"],
        [name: :default, type: :text, placeholder: "e.g. medium"],
        [name: :doc, type: :textarea],
        [name: :weight, type: :number],
        [name: :kind, type: :select, options: [{"One", "one"}]],
        [name: :pinned, type: :checkbox]
      ]

      field =
        NestedForm
        |> FormInfo.field(:tags)
        |> Map.update!(:nested_fields, fn [first | rest] ->
          [first |> Map.put(:type, :key_map) |> Map.put(:options, keys) | rest]
        end)

      %{html: render_form(field)}
    end

    test "and draws it through the adapter, not by hand", %{html: html} do
      assert html =~ ~s|type="number"|
      assert html =~ "<select"
      assert html =~ "<textarea"
      assert html =~ ~s|type="checkbox"|
      assert html =~ "e.g. medium", "a key's placeholder reaches its control"
      assert html =~ "Required", "and its label"
    end

    # A toggle or checkbox left off sends nothing at all, so the hidden companion is the only thing
    # that makes "off" reachable — without it, unticking could only leave the previous value standing.
    test "with the hidden companion every unticked box needs", %{html: html} do
      assert html =~ ~s|type="hidden"|
      assert html =~ ~s|value="false"|
    end

    # `parent[index][sub_field][key]` — the shape a form already posts for a nested map, so nothing
    # downstream has to learn a new one.
    test "named the way a form posts a nested map", %{html: html} do
      assert html =~ "[name][required]"
      assert html =~ "[name][kind]"
    end

    test "and a key map with nothing declared draws nothing rather than raising" do
      field =
        NestedForm
        |> FormInfo.field(:tags)
        |> Map.update!(:nested_fields, fn [first | rest] ->
          [first |> Map.put(:type, :key_map) |> Map.put(:options, []) | rest]
        end)

      assert is_binary(render_form(field))
    end
  end

  # A LIST OF KEY MAPS, one row of controls per entry. The rows live one level inside a
  # constrained-map row, which is the one place `add_nested`/`remove_nested` cannot reach — so the
  # buttons carry the whole address, and a render that drops any part of it silently makes them
  # no-ops.
  describe "a key list draws a row of controls per entry" do
    setup do
      keys = [
        [name: :name, type: :text, placeholder: "e.g. label"],
        [name: :type, type: :select, options: ~w(string integer)],
        [name: :required, type: :toggle, label: "Required"]
      ]

      field =
        ConstrainedMapForm
        |> FormInfo.field(:slots)
        |> Map.update!(:nested_fields, fn [first | rest] ->
          [
            first
            |> Map.put(:name, :attrs)
            |> Map.put(:type, :key_list)
            |> Map.put(:options, keys)
            |> Map.put(:add_label, "+ Add Attribute")
            |> Map.put(:remove_label, "Drop it")
            | rest
          ]
        end)

      form =
        ConstrainedMapForm
        |> AshPhoenix.Form.for_create(:create, forms: [auto?: false])
        |> AshPhoenix.Form.validate(%{
          "slots" => %{
            "0" => %{"attrs" => %{"0" => %{"name" => "label", "required" => "true"}}}
          }
        })
        |> Phoenix.Component.to_form()

      %{html: render_form(field, form)}
    end

    test "with the buttons that add one and take one away", %{html: html} do
      assert html =~ ~s|phx-click="add_key_row"|
      assert html =~ ~s|phx-click="remove_key_row"|
      assert html =~ "+ Add Attribute", "the declaration names the add button"
      assert html =~ "Drop it", "and the remove one"
    end

    # Every part of the address comes from the declaration, and every part is checked against it
    # again on the way back — so all of it has to be on the button for the event to do anything.
    test "each naming the field, the row it sits in, itself, and which row to drop", %{html: html} do
      assert html =~ ~s|phx-value-field="slots"|
      assert html =~ ~s|phx-value-index="0"|
      assert html =~ ~s|phx-value-sub="attrs"|
      assert html =~ ~s|phx-value-row="0"|
    end

    test "and draws the row it was given, through the adapter", %{html: html} do
      assert html =~ ~s|name="form[slots][0][attrs][0][name]"|
      assert html =~ ~s|value="label"|
      assert html =~ ~s|name="form[slots][0][attrs][0][type]"|
      assert html =~ ~s|name="form[slots][0][attrs][0][required]"|
    end

    # A FORM CANNOT POST AN EMPTY LIST. Without the sentinel the key is simply missing once the last
    # row goes, and "missing" reads as "unchanged" everywhere downstream.
    test "with the sentinel that lets an empty list be posted at all", %{html: html} do
      assert html =~ ~s|name="form[slots][0][attrs][_empty]"|
    end
  end
end

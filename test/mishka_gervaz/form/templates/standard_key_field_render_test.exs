defmodule MishkaGervaz.Form.Templates.StandardKeyFieldRenderTest do
  @moduledoc """
  `:key_map` and `:key_list` as fields in their own right, rather than as sub-fields of a nested row.

  The two were reachable only inside a `field … :nested`, because the template dispatches a
  top-level field through `render_input/4` and a sub-field through `sub_field_input/1`, and only the
  second knew about them. A `{:array, :map}` column whose entries have a fixed shape — a list of
  social links, a set of redirects — had no choice but `:json`.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ConstrainedMapForm

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

  # Opening a SAVED record, which is the everyday case and the one that was broken: a value read back
  # off the record has been cast, and Ash hands the declared fields of a map back with atom keys,
  # while raw form params keep string keys. A reader that knew only one of the two drew every row of
  # every stored key map and key list as empty.
  defp with_record(attrs) do
    struct(ConstrainedMapForm, Map.merge(%{id: Ash.UUID.generate(), title: "t"}, attrs))
    |> AshPhoenix.Form.for_update(:update, forms: [auto?: false])
    |> Phoenix.Component.to_form()
  end

  defp with_params(params) do
    ConstrainedMapForm
    |> AshPhoenix.Form.for_create(:create, forms: [auto?: false])
    |> AshPhoenix.Form.validate(params)
    |> Phoenix.Component.to_form()
  end

  describe "a top-level key list" do
    setup do
      %{field: FormInfo.field(ConstrainedMapForm, :links)}
    end

    test "draws a row of controls per entry", %{field: field} do
      html =
        render_form(
          field,
          with_params(%{"links" => %{"0" => %{"platform" => "github", "url" => "https://gh"}}})
        )

      assert html =~ ~s|name="form[links][0][platform]"|
      assert html =~ ~s|name="form[links][0][url]"|
      assert html =~ ~s|value="github"|
      assert html =~ "e.g. github", "a key's placeholder reaches its control"
    end

    # The rows of a constrained-map field are what `add_nested` and `remove_nested` have always
    # added and removed, so a top-level key list asks them rather than a third pair of events.
    test "with the buttons the existing events answer", %{field: field} do
      html = render_form(field)

      assert html =~ ~s|phx-click="add_nested"|
      assert html =~ ~s|phx-value-field="links"|
      assert html =~ "+ Add Link", "the declaration names the add button"
    end

    test "and a remove that names the row to drop", %{field: field} do
      html =
        render_form(field, with_params(%{"links" => %{"0" => %{"platform" => "github"}}}))

      assert html =~ ~s|phx-click="remove_nested"|
      assert html =~ ~s|phx-value-index="0"|
      assert html =~ "Drop"
    end

    # A form cannot post an empty list, so the key has to be able to say it holds nothing.
    test "and the marker that lets an empty list be posted", %{field: field} do
      assert render_form(field) =~ ~s|name="form[links][_empty]"|
    end

    test "and a saved record's rows come back filled, not blank", %{field: field} do
      html =
        render_form(field, with_record(%{links: [%{platform: "github", url: "https://gh"}]}))

      assert html =~ ~s|value="github"|
      assert html =~ ~s|value="https://gh"|
    end

    test "a list with nothing in it draws the add button and no rows", %{field: field} do
      html = render_form(field)

      refute html =~ ~s|name="form[links][0][platform]"|
      assert html =~ ~s|phx-click="add_nested"|
    end
  end

  describe "a top-level key map" do
    setup do
      %{field: FormInfo.field(ConstrainedMapForm, :settings)}
    end

    test "draws one control per declared key", %{field: field} do
      html = render_form(field, with_params(%{"settings" => %{"theme" => "dark"}}))

      assert html =~ ~s|name="form[settings][theme]"|
      assert html =~ ~s|name="form[settings][compact]"|
      assert html =~ ~s|value="dark"|
      assert html =~ "Theme"
      assert html =~ "Compact"
    end

    # There is nothing to add or remove — the keys are the declaration — so neither button is drawn
    # and neither marker is needed.
    test "and nothing to add or remove", %{field: field} do
      html = render_form(field)

      refute html =~ ~s|phx-click="add_nested"|
      refute html =~ ~s|name="form[settings][_empty]"|
    end

    test "and a saved record's keys come back filled", %{field: field} do
      html = render_form(field, with_record(%{settings: %{theme: "dark", compact: true}}))

      assert html =~ ~s|value="dark"|
      assert html =~ "checked", "the toggle reads the stored boolean"
    end

    test "an unset map still draws its keys", %{field: field} do
      html = render_form(field)

      assert html =~ ~s|name="form[settings][theme]"|
    end
  end
end

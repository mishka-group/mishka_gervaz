defmodule MishkaGervaz.Form.Templates.StandardLabelLinkTest do
  @moduledoc """
  A field's label names its control: `for` on the label and the same `id` on the one element a
  control is, or the label's `id` as the `aria-labelledby` of a control drawn as a group of
  elements. The ids are the form's own, so two forms on one page never share one.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ConstrainedMapForm
  alias MishkaGervaz.Test.Resources.FormPost
  alias MishkaGervaz.Test.Resources.NestedForm
  alias MishkaGervaz.Test.Resources.StringListForm

  defp render_form(fields, id \\ "post", form \\ nil) do
    state =
      build_state(
        static_opts: [id: id, fields: fields, groups: []],
        mode: :create,
        form: form || to_form(%{}, as: :form, id: "#{id}-form")
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

  defp fields(resource, names), do: Enum.map(names, &FormInfo.field(resource, &1))

  # A row of `slots` whose first sub-field is a key list, held by the AshPhoenix form a
  # constrained map draws its rows from.
  defp slots_with_key_list(id) do
    field =
      ConstrainedMapForm
      |> FormInfo.field(:slots)
      |> Map.update!(:nested_fields, fn [first | rest] ->
        [
          first
          |> Map.put(:name, :attrs)
          |> Map.put(:type, :key_list)
          |> Map.put(:options, [[name: :name, type: :text, label: "Name"]])
          | rest
        ]
      end)

    form =
      ConstrainedMapForm
      |> AshPhoenix.Form.for_create(:create, as: "form", id: "#{id}-form", forms: [auto?: false])
      |> AshPhoenix.Form.validate(%{
        "slots" => %{"0" => %{"attrs" => %{"0" => %{"name" => "a"}}}}
      })
      |> Phoenix.Component.to_form()

    {field, form}
  end

  defp ids(html), do: values(html, ~r/\sid="([^"]+)"/)
  defp label_fors(html), do: values(html, ~r/<label\b[^>]*?\sfor="([^"]+)"/s)
  defp labelled_by(html), do: values(html, ~r/aria-labelledby="([^"]+)"/)

  defp values(html, regex),
    do: regex |> Regex.scan(html, capture: :all_but_first) |> List.flatten()

  defp control_with_id?(html, id),
    do: html =~ ~r/<(input|select|textarea|button)\b[^>]*\sid="#{Regex.escape(id)}"/s

  @single [:title, :content, :status, :language, :priority, :featured, :metadata, :user_id]

  describe "a field drawn as one element" do
    for name <- @single do
      test "#{name}'s label names its control" do
        html = render_form(fields(FormPost, [unquote(name)]))
        id = "post-form_#{unquote(name)}"

        assert id in label_fors(html)
        assert control_with_id?(html, id)
      end
    end
  end

  describe "a field drawn as a group of elements" do
    for {resource, name} <- [
          {StringListForm, :tags},
          {ConstrainedMapForm, :links},
          {ConstrainedMapForm, :settings},
          {NestedForm, :items}
        ] do
      test "#{name} of #{inspect(resource)} is a group its label's id names" do
        html = render_form(fields(unquote(resource), [unquote(name)]))
        label_id = "post-form_#{unquote(name)}-label"

        assert html =~ ~r/<label\b[^>]*\sid="#{label_id}"/s
        refute html =~ ~r/<label\b[^>]*\sid="#{label_id}"[^>]*\sfor=/s
        assert html =~ ~r/role="group"[^>]*aria-labelledby="#{label_id}"/s
      end
    end
  end

  describe "a nested field's rows" do
    setup do
      {field, form} = slots_with_key_list("post")
      %{html: render_form([field], "post", form)}
    end

    test "are a group the field's label names", %{html: html} do
      assert html =~ ~r/<label\b[^>]*\sid="post-form_slots-label"/s
      assert html =~ ~r/role="group"[^>]*aria-labelledby="post-form_slots-label"/s
    end

    test "name each sub-field by its label, and a key list sub-field by its label's id",
         %{html: html} do
      on_page = MapSet.new(ids(html))

      assert label_fors(html) != []
      for id <- label_fors(html), do: assert(id in on_page, "no element has the id #{id}")

      [key_list_label] =
        Regex.run(~r/<label\b[^>]*\sid="([^"]*_attrs-label)"/s, html, capture: :all_but_first)

      refute html =~ ~r/<label\b[^>]*\sid="#{key_list_label}"[^>]*\sfor=/s
      assert html =~ ~r/role="group"[^>]*aria-labelledby="#{key_list_label}"/s
    end
  end

  test "a checkbox keeps its own label, and the field's label names nothing else" do
    field = Map.put(FormInfo.field(FormPost, :featured), :type, :checkbox)
    html = render_form([field])

    refute "post-form_featured" in label_fors(html)

    assert html =~
             ~r/<label[^>]*>\s*<input[^>]*type="hidden"[^>]*>\s*<input[^>]*id="post-form_featured"/s
  end

  describe "a whole form" do
    test "names only elements that are on the page" do
      html =
        render_form(
          fields(FormPost, @single) ++
            fields(ConstrainedMapForm, [:links, :settings]) ++
            fields(StringListForm, [:tags])
        )

      on_page = MapSet.new(ids(html))

      assert label_fors(html) != []
      for id <- label_fors(html), do: assert(id in on_page, "no element has the id #{id}")

      for ref <- labelled_by(html),
          id <- String.split(ref),
          do: assert(id in on_page, "no element has the id #{id}")
    end

    test "uses each id once" do
      html = render_form(fields(FormPost, @single) ++ fields(StringListForm, [:tags]))
      all = ids(html)

      assert all -- Enum.uniq(all) == []
    end
  end

  test "two forms on one page share no id" do
    a = render_form(fields(FormPost, @single), "a")
    b = render_form(fields(FormPost, @single), "b")

    assert MapSet.disjoint?(MapSet.new(ids(a)), MapSet.new(ids(b)))
    assert "a-form_title" in label_fors(a)
    assert "b-form_title" in label_fors(b)
  end
end

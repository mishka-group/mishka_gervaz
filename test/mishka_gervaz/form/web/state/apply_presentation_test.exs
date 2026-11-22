defmodule MishkaGervaz.Form.Web.State.ApplyPresentationTest do
  @moduledoc """
  A mount's own presentation choices, over the ones the resource declared.

  The resource has one `form` section; the surfaces that mount it do not know the same things. The
  Media library has to ask which site a file belongs to. The page builder's Assets sheet already
  knows, because the page being edited belongs to one — so it hides the field and has no Create
  button, because its dropzone is the submit.

  What is pinned here is that BOTH of those are opt-in: a mount that passes neither assign gets a
  state identical to the one it got before this existed.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State
  alias MishkaGervaz.Form.Web.State.Static

  defp state(fields, groups \\ []) do
    %State{
      static: %Static{
        id: "form",
        resource: Some.Resource,
        fields: fields,
        groups: groups,
        submit: %{create: %{label: "Create"}}
      },
      mode: :create
    }
  end

  defp field(name), do: %{name: name, type: :text}

  describe "hidden_fields" do
    test "a hidden field leaves the field list" do
      result =
        [field(:site_id), field(:media_category_id), field(:featured)]
        |> state()
        |> State.apply_presentation(%{hidden_fields: [:site_id]})

      assert Enum.map(result.static.fields, & &1.name) == [:media_category_id, :featured]
    end

    # A GROUP CARRIES THE FIELD TWICE — once as a name, once resolved — and the template renders the
    # resolved ones. Dropping only one of the two leaves the field on screen or leaves the group
    # claiming a field that no longer exists.
    test "it leaves the groups that named it, in both forms" do
      fields = [field(:site_id), field(:media_category_id)]

      groups = [
        %{
          name: :upload_fields,
          fields: [:site_id, :media_category_id],
          resolved_fields: fields
        }
      ]

      result =
        fields
        |> state(groups)
        |> State.apply_presentation(%{hidden_fields: [:site_id]})

      assert [%{fields: [:media_category_id], resolved_fields: [%{name: :media_category_id}]}] =
               result.static.groups
    end

    # THE COLUMN COUNT IS NOT TOUCHED HERE. A group's width is decided when it is drawn, by the
    # fields it is about to draw — `render_group_fields/3` in the standard template — because
    # `hidden_fields` is only one of three reasons a declared field goes unrendered; `show_on` and
    # `restricted` are the others, and neither is known at init.
    test "the declared columns survive hiding, for the template to narrow" do
      groups = [
        %{
          name: :upload_fields,
          fields: [:site_id, :media_category_id, :featured],
          resolved_fields: [],
          ui: %{columns: 3}
        }
      ]

      result =
        []
        |> state(groups)
        |> State.apply_presentation(%{hidden_fields: [:site_id]})

      assert [%{fields: [:media_category_id, :featured], ui: %{columns: 3}}] =
               result.static.groups
    end

    test "hiding nothing changes nothing" do
      original = state([field(:site_id)], [%{name: :g, fields: [:site_id]}])

      assert State.apply_presentation(original, %{}) == original
      assert State.apply_presentation(original, %{hidden_fields: []}) == original
      assert State.apply_presentation(original, %{hidden_fields: nil}) == original
    end

    test "a name no field has is not an error" do
      original = state([field(:featured)])

      assert State.apply_presentation(original, %{hidden_fields: [:nonexistent]}) == original
    end
  end

  describe "submit" do
    test "a form draws its submit row unless the mount says otherwise" do
      assert state([]).static.submit_visible?
      assert State.apply_presentation(state([]), %{}).static.submit_visible?
      assert State.apply_presentation(state([]), %{submit: true}).static.submit_visible?
    end

    test "false hides it" do
      refute State.apply_presentation(state([]), %{submit: false}).static.submit_visible?
    end

    test ":external hides it for a create and for an edit, and says the page draws the buttons" do
      result = State.apply_presentation(state([]), %{submit: :external})

      refute result.static.submit_visible?
      assert result.static.submit_external?
      refute State.apply_presentation(state([]), %{submit: false}).static.submit_external?
    end

    # THE BUTTON GOES, THE ACTION STAYS. `Events.do_handle("save", …)` asks the SUBMIT CONFIG whether
    # the save is allowed; clearing that instead of the flag would make a dropzone-submitted form
    # silently unsubmittable.
    test "hiding the row leaves the submit config alone" do
      result = State.apply_presentation(state([]), %{submit: false})

      assert result.static.submit == %{create: %{label: "Create"}}
    end
  end

  describe "submit_alternatives" do
    @alt %{id: "empty", label: "Create empty & open editor", navigate: "/builder/page"}

    test "a form offers none unless the mount names them" do
      assert state([]).static.submit_alternatives == []
      assert State.apply_presentation(state([]), %{}).static.submit_alternatives == []
    end

    test "the mount's list is what the submit row offers" do
      result = State.apply_presentation(state([]), %{submit_alternatives: [@alt]})

      assert result.static.submit_alternatives == [@alt]
    end

    test "an empty list is the same as saying nothing" do
      original = state([])

      assert State.apply_presentation(original, %{submit_alternatives: []}) == original
      assert State.apply_presentation(original, %{submit_alternatives: nil}) == original
    end

    # AN ALTERNATIVE IS ANOTHER WAY TO CREATE, so a form that is editing must not offer one — the
    # menu would read as "and here is a second thing to do to this record".
    test "the standard template offers them while creating only" do
      source = File.read!("lib/mishka_gervaz/form/templates/standard.ex")

      assert source =~
               "defp alternatives_for(%{submit_alternatives: alternatives}, %{mode: :create}, false)"

      assert source =~ "defp alternatives_for(_static, _state, _submit_disabled), do: []"
    end

    # THE MENU CLOSES ITSELF, both ways. It is shown by a JS command, so its open state is a sticky
    # inline style no server render can clear — and a modal dismissed with escape would otherwise
    # come back with the menu already hanging open over the form.
    test "the menu closes on a click away and on escape" do
      source = File.read!("lib/mishka_gervaz/form/templates/standard.ex")

      assert source =~ ~s|phx-click-away={JS.hide(to: "#" <> @alt_menu_id)}|
      assert source =~ ~s|phx-window-keydown={JS.hide(to: "#" <> @alt_menu_id)}|
      assert source =~ ~s(phx-key="escape")
    end

    # A SUBMIT THAT WOULD BE REFUSED IS NOT AN ALTERNATIVE. `Events.do_handle("save", …)` asks the
    # submit config before it acts, so while the button is disabled an item that submits this form
    # does nothing at all — while one that LEAVES is exactly what a reader who cannot save wants.
    test "a disabled submit keeps the links and drops the submitting items" do
      source = File.read!("lib/mishka_gervaz/form/templates/standard.ex")

      assert source =~
               "defp alternatives_for(%{submit_alternatives: alternatives}, %{mode: :create}, true)"

      assert source =~ "do: Enum.filter(alternatives, &Map.has_key?(&1, :navigate))"
      assert source =~ "alternatives_for(assigns.static, state, submit_disabled)"
    end

    # A LINK LEAVES, A BUTTON SUBMITS — the difference is `:navigate`, and it decides which of the
    # two clauses draws the item.
    test "an item with a path is a link, and one without is a submit of this form" do
      source = File.read!("lib/mishka_gervaz/form/templates/standard.ex")

      assert source =~ "defp alternative(%{alt: %{navigate: path}} = assigns)"
      assert source =~ ~s(navigate={@path})
      assert source =~ ~s(type="submit")
    end
  end

  test "both at once" do
    result =
      [field(:site_id), field(:featured)]
      |> state()
      |> State.apply_presentation(%{hidden_fields: [:site_id], submit: false})

    assert Enum.map(result.static.fields, & &1.name) == [:featured]
    refute result.static.submit_visible?
  end

  test "assigns that are not a map are ignored" do
    original = state([field(:site_id)])

    assert State.apply_presentation(original, nil) == original
  end

  # THE FLAG IS ONLY WORTH SETTING IF SOMETHING READS IT, and the two readers need a mounted
  # LiveComponent to exercise — so what is asserted is the wiring, at the lines that make it.
  describe "the wiring" do
    # AND ONLY WHILE CREATING. A form loaded with a record and no submit is one you can change and
    # cannot save — the mount asked for no button because a DROP submits a new file, and an edit has
    # no drop.
    test "the standard template hides the submit row for a create, not for an edit" do
      source = File.read!("lib/mishka_gervaz/form/templates/standard.ex")

      assert source =~
               "defp render_submit(%{static: %{submit_visible?: false}, state: %{mode: :create}} = assigns)"
    end

    test "the standard template hides the submit row of a mount that draws its own buttons, in every mode" do
      source = File.read!("lib/mishka_gervaz/form/templates/standard.ex")

      assert source =~ "defp render_submit(%{static: %{submit_external?: true}} = assigns)"
    end

    test "the component applies a mount's choices at init" do
      source = File.read!("lib/mishka_gervaz/form/web/live.ex")

      assert source =~ "State.apply_presentation(assigns)"
    end
  end
end

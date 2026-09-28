defmodule MishkaGervaz.Form.Web.Events.SaveErrorsTest do
  @moduledoc """
  What a failed save shows.

  An id a relation field sends is saved by a nested action, so its error comes back under the
  field's path, `[:label_ids, 0]`. AshPhoenix shows only the errors of a path that has a nested form,
  and a relation field has none. Each case here saves through the real `save` event and checks the
  message reaches the field, or the form when no field can show it.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Form.Web.Events

  alias MishkaGervaz.Test.Resources.{
    RelationErrorArticle,
    RelationErrorArticleLabel,
    RelationErrorLabel
  }

  @title %{
    name: :title,
    type: :text,
    required: true,
    disabled: false,
    options: [],
    ui: %{label: "Title", placeholder: nil, class: nil},
    depends_on: nil
  }

  @labels %{
    name: :label_ids,
    type: :relation,
    required: false,
    disabled: false,
    options: [],
    ui: %{label: "Labels", placeholder: nil, class: nil},
    depends_on: nil
  }

  setup do
    for resource <- [RelationErrorArticleLabel, RelationErrorArticle, RelationErrorLabel] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    :ok
  end

  defp label!(name), do: Ash.create!(RelationErrorLabel, %{name: name})

  defp save(label_ids, opts \\ []) do
    fields = Keyword.get(opts, :fields, [@title, @labels])
    action = Keyword.get(opts, :action, :create)

    form =
      RelationErrorArticle
      |> AshPhoenix.Form.for_create(action, actor: %{id: "user-1", role: :admin})
      |> Phoenix.Component.to_form()

    state =
      build_state(
        mode: :create,
        form: form,
        field_values: %{label_ids: label_ids},
        static_opts: [fields: fields, groups: []]
      )

    title = Keyword.get(opts, :title, "An article")

    params =
      if Enum.any?(fields, &(&1.name == :label_ids)),
        do: %{"title" => title},
        else: %{"title" => title, "label_ids" => label_ids}

    {:noreply, socket} = Events.handle("save", %{"form" => params}, build_socket(state))

    socket.assigns.form_state
  end

  describe "an error on one id of a relation field" do
    test "a refused id is said on that field" do
      state = save([label!("ours").id, label!("foreign").id])

      assert state.errors[:label_ids] == ["That label is not one this site can use."]
      assert state.form_errors == []
    end

    test "an id with no record is said on that field" do
      state = save([Ash.UUID.generate()])

      assert state.errors[:label_ids] == ["could not be found"]
      assert state.form_errors == []
    end

    test "is said on the form when the form has no such field" do
      state = save([label!("foreign").id], fields: [@title, %{@labels | name: :other_ids}])

      assert state.form_errors == ["That label is not one this site can use."]
    end

    test "leaves a clean save alone" do
      state = save([label!("ours").id])

      assert state.errors == %{}
      assert state.form_errors == []
      assert [%{title: "An article"}] = Ash.read!(RelationErrorArticle)
    end
  end

  describe "an error said on the form names its field" do
    test "a message that is not a sentence follows the field's name" do
      state = save([Ash.UUID.generate()], fields: [@title, %{@labels | name: :other_ids}])

      assert state.form_errors == ["Label ids could not be found"]
    end

    test "so does an error on an attribute the form does not show" do
      state = save([], fields: [@labels], title: nil)

      assert state.form_errors == ["Title is required"]
    end
  end

  describe "in Persian" do
    setup do
      Gettext.put_locale(MishkaGervaz.Test.Gettext, "fa")
      :ok
    end

    test "an error on a field is said in Persian" do
      state = save([Ash.UUID.generate()])

      assert state.errors[:label_ids] == ["پیدا نشد"]
    end

    test "an error on the form names its field in Persian" do
      state = save([Ash.UUID.generate()], fields: [@title, %{@labels | name: :other_ids}])

      assert state.form_errors == ["«برچسب‌ها» پیدا نشد"]
    end

    test "a sentence on the form is said alone, in Persian" do
      state = save([label!("foreign").id], fields: [@title, %{@labels | name: :other_ids}])

      assert state.form_errors == ["این برچسب را این سایت نمی‌تواند به کار ببرد."]
    end

    test "an error on an attribute the form does not show names it in Persian" do
      state = save([], fields: [@labels], title: nil)

      assert state.form_errors == ["«عنوان» الزامی است"]
    end

    test "a save no error of which can be shown says so in Persian" do
      state = save([], action: :locked_create)

      assert state.form_errors == ["تغییرها ذخیره نشد."]
    end
  end

  describe "a save no error of which can be shown" do
    test "says the changes were not saved" do
      state = save([], action: :locked_create)

      assert state.errors == %{}
      assert state.form_errors == ["The changes were not saved."]
    end
  end

  describe "render_form_errors/1" do
    test "draws every message above the submit row" do
      state = save([label!("foreign").id], fields: [@title, %{@labels | name: :other_ids}])

      html =
        render_component(&Standard.render_form_errors/1,
          state: state,
          static: state.static,
          myself: nil
        )

      assert html =~ ~s|id="test-form-form-errors"|
      assert html =~ ~s|role="alert"|
      assert html =~ "That label is not one this site can use."
    end

    test "draws nothing when there are none" do
      state = build_state(static_opts: [fields: [@title]])

      assert render_component(&Standard.render_form_errors/1,
               state: state,
               static: state.static,
               myself: nil
             ) == ""
    end
  end
end

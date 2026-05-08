defmodule MishkaGervaz.Form.DSL.SubmitTest do
  @moduledoc """
  Tests for the form `submit` DSL entity (`MishkaGervaz.Form.Dsl.Submit`).

  Pins the entity shape and per-button structure: create / update / cancel
  buttons (each a singleton sub-entity), the `ui` sub-entity, and the
  position field. Uses the populated `FormPost`, the per-button
  `SubmitOptionsForm`, and the empty `NoButtonsForm` fixtures.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    FormPost,
    SubmitOptionsForm,
    NoButtonsForm,
    MinimalForm
  }

  describe "FormPost — populated submit block" do
    test "submit map contains all three buttons" do
      submit = FormInfo.submit(FormPost)
      assert is_map(submit)
      assert is_map(submit.create)
      assert is_map(submit.update)
      assert is_map(submit.cancel)
    end

    test "create button label is set" do
      submit = FormInfo.submit(FormPost)
      assert submit.create.label == "Create Post"
    end

    test "update button label is set" do
      submit = FormInfo.submit(FormPost)
      assert submit.update.label == "Save Post"
    end

    test "cancel button label is set" do
      submit = FormInfo.submit(FormPost)
      assert submit.cancel.label == "Discard"
    end

    test "position is :bottom" do
      submit = FormInfo.submit(FormPost)
      assert submit.position == :bottom
    end

    test "ui block populates submit_class / cancel_class / wrapper_class / extra" do
      submit = FormInfo.submit(FormPost)
      assert submit.ui.submit_class == "bg-blue-600 text-white"
      assert submit.ui.cancel_class == "bg-gray-200"
      assert submit.ui.wrapper_class == "flex gap-4"
      assert submit.ui.extra == %{rounded: true}
    end
  end

  describe "SubmitOptionsForm — per-button options (inline + block syntax)" do
    test "create uses inline keyword form with disabled / restricted" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.create.label == "Create Item"
      assert submit.create.disabled == false
      assert submit.create.restricted == true
    end

    test "update uses block form with function-based disabled / restricted / visible" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.update.label == "Save Item"
      assert is_function(submit.update.disabled, 1)
      assert is_function(submit.update.restricted, 1)
      assert is_function(submit.update.visible, 1)
    end

    test "cancel uses inline form with visible: false" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.cancel.label == "Go Back"
      assert submit.cancel.visible == false
    end

    test "position is :top" do
      submit = FormInfo.submit(SubmitOptionsForm)
      assert submit.position == :top
    end
  end

  describe "NoButtonsForm — empty submit inherits from domain" do
    test "all three buttons fall back to the test domain's submit" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.create.label == "Save"
      assert submit.update.label == "Save Changes"
      assert submit.cancel.label == "Cancel"
    end

    test "position from the resource block is preserved" do
      submit = FormInfo.submit(NoButtonsForm)
      assert submit.position == :bottom
    end
  end

  describe "MinimalForm — no submit block at all" do
    test "submit inherits the entire domain submit" do
      submit = FormInfo.submit(MinimalForm)
      assert submit.create.label == "Save"
      assert submit.update.label == "Save Changes"
      assert submit.cancel.label == "Cancel"
      assert submit.position == :bottom
    end
  end

  describe "Submit entity declaration" do
    alias MishkaGervaz.Form.Dsl.Submit, as: SubmitDsl

    test "entity/0 returns a singleton submit entity" do
      entity = SubmitDsl.entity()
      assert entity.name == :submit
      assert :submit in entity.singleton_entity_keys
    end

    test "entity points at the Submit struct as target" do
      entity = SubmitDsl.entity()
      assert entity.target == MishkaGervaz.Form.Entities.Submit
    end

    test "entity declares create / update / cancel / ui sub-entities" do
      entity = SubmitDsl.entity()
      sub_entity_names = Keyword.keys(entity.entities)

      for name <- [:create, :update, :cancel, :ui] do
        assert name in sub_entity_names, "missing sub-entity: #{name}"
      end
    end

    test "create / update / cancel sub-entities use Submit.Button as target" do
      entity = SubmitDsl.entity()

      for name <- [:create, :update, :cancel] do
        [sub] = Keyword.get(entity.entities, name)
        assert sub.target == MishkaGervaz.Form.Entities.Submit.Button
        assert name in sub.singleton_entity_keys
      end
    end

    test "ui sub-entity uses Submit.Ui as target" do
      entity = SubmitDsl.entity()
      [ui] = Keyword.get(entity.entities, :ui)
      assert ui.target == MishkaGervaz.Form.Entities.Submit.Ui
      assert :ui in ui.singleton_entity_keys
    end

    test "transform function is wired to Submit.transform/1" do
      entity = SubmitDsl.entity()
      assert entity.transform == {MishkaGervaz.Form.Entities.Submit, :transform, []}
    end
  end
end

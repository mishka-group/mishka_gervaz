defmodule MishkaGervaz.Form.Transformers.SubmitMergeTest do
  @moduledoc """
  Verifies the submit merge rules between resource and domain `submit` blocks.

  Rules under test (from TODO_Submit_Domain.md):

    1. Resource is the first priority; domain is the second.
    2. Per-button merge: a button defined in the resource overrides the same
       button in the domain.
    3. Buttons NOT defined in the resource fall back to the domain.
    4. `active: false` on a resource button suppresses inheritance from the
       domain (the button is not rendered).
    5. A resource without a `submit` block at all inherits the entire domain
       submit configuration.
    6. A resource that declares buttons without labels resolves labels by
       falling back to the domain label, then to the hard default for the
       button kind (`Create`, `Save Changes`, `Cancel`).
    7. `position` follows the same priority (resource > domain > `:bottom`).
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo

  alias MishkaGervaz.Test.Resources.{
    SubmitMergeNoBlock,
    SubmitMergePartialResource,
    SubmitMergeOverrideLabels,
    SubmitMergeActiveFalse,
    SubmitMergeBareButtons,
    SubmitMergePartialDomainResource
  }

  describe "resource without a submit block (rule 5)" do
    test "inherits all three buttons from the domain" do
      submit = FormInfo.submit(SubmitMergeNoBlock)
      assert submit.create.label == "Domain Create"
      assert submit.update.label == "Domain Update"
      assert submit.cancel.label == "Domain Cancel"
    end

    test "inherits the domain position" do
      submit = FormInfo.submit(SubmitMergeNoBlock)
      assert submit.position == :bottom
    end

    test "inherited buttons normalize the per-button options" do
      submit = FormInfo.submit(SubmitMergeNoBlock)

      for kind <- [:create, :update, :cancel] do
        button = Map.fetch!(submit, kind)
        assert button.disabled == false
        assert button.restricted == false
        assert button.visible == true
        assert button.active == true
      end
    end
  end

  describe "resource with partial submit (rules 2 and 3)" do
    test "create and update come from the resource" do
      submit = FormInfo.submit(SubmitMergePartialResource)
      assert submit.create.label == "Resource Create"
      assert submit.update.label == "Resource Update"
    end

    test "cancel falls back to the domain button" do
      submit = FormInfo.submit(SubmitMergePartialResource)
      assert submit.cancel.label == "Domain Cancel"
    end

    test "position follows resource priority over domain (rule 7)" do
      submit = FormInfo.submit(SubmitMergePartialResource)
      assert submit.position == :top
    end
  end

  describe "resource overrides every button (rule 1)" do
    test "every label is the resource label" do
      submit = FormInfo.submit(SubmitMergeOverrideLabels)
      assert submit.create.label == "Resource Create"
      assert submit.update.label == "Resource Update"
      assert submit.cancel.label == "Resource Cancel"
    end
  end

  describe "active: false suppresses inheritance (rule 4)" do
    test "the suppressed button is nil even though the domain provides one" do
      submit = FormInfo.submit(SubmitMergeActiveFalse)
      assert submit.cancel == nil
    end

    test "other buttons remain unaffected" do
      submit = FormInfo.submit(SubmitMergeActiveFalse)
      assert submit.create.label == "Resource Create"
      assert submit.update.label == "Resource Update"
    end
  end

  describe "bare buttons resolve labels through fallback chain (rule 6)" do
    test "labels fall back to the domain label" do
      submit = FormInfo.submit(SubmitMergeBareButtons)
      assert submit.create.label == "Domain Create"
      assert submit.update.label == "Domain Update"
      assert submit.cancel.label == "Domain Cancel"
    end
  end

  describe "partial domain — domain only defines cancel" do
    test "cancel is taken from the domain" do
      submit = FormInfo.submit(SubmitMergePartialDomainResource)
      assert submit.cancel.label == "Partial Cancel"
    end

    test "create and update come from the resource" do
      submit = FormInfo.submit(SubmitMergePartialDomainResource)
      assert submit.create.label == "Resource Create"
      assert submit.update.label == "Resource Update"
    end
  end

  describe "active accepts boolean and function (rule 11)" do
    test "default active is true" do
      submit = FormInfo.submit(SubmitMergeOverrideLabels)
      assert submit.create.active == true
      assert submit.update.active == true
      assert submit.cancel.active == true
    end
  end
end

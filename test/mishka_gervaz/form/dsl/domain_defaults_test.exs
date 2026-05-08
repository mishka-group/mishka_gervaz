defmodule MishkaGervaz.Form.DSL.DomainDefaultsTest do
  @moduledoc """
  Tests for the domain-level form DSL section
  (`MishkaGervaz.Form.Dsl.DomainDefaults`).

  Pins the section shape (top-level schema, sub-sections, embedded
  `submit` entity) and verifies inheritance from a populated domain via
  `MishkaGervaz.Domain.Info.Form` accessors. Uses `Test.Domain` for the
  full case and `SubmitMergeDomain` for the populated submit block.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Domain.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Domain
  alias MishkaGervaz.Test.Resources.SubmitMergeDomain

  describe "Test.Domain — top-level form schema" do
    test "actor_key is set" do
      assert FormInfo.actor_key(Domain) == :current_user
    end

    test "master_check is a function/1" do
      check = FormInfo.master_check(Domain)
      assert is_function(check, 1)
    end

    test "ui_adapter is the Tailwind adapter" do
      assert FormInfo.ui_adapter(Domain) == MishkaGervaz.UIAdapters.Tailwind
    end

    test "template is the standard form template" do
      assert FormInfo.template(Domain) == MishkaGervaz.Form.Templates.Standard
    end

    test "features defaults to :all" do
      assert FormInfo.features(Domain) == :all
    end
  end

  describe "Test.Domain — actions sub-section" do
    test "actions map contains create / update / read tuples" do
      actions = FormInfo.actions(Domain)
      assert actions.create == {:master_create, :create}
      assert actions.update == {:master_update, :update}
      assert actions.read == {:master_get, :read}
    end
  end

  describe "Test.Domain — layout sub-section" do
    test "layout responsive flag is true" do
      assert FormInfo.layout(Domain).responsive == true
    end
  end

  describe "Test.Domain — theme sub-section" do
    test "theme is nil when no `theme do ... end` block is declared" do
      assert FormInfo.theme(Domain) == nil
    end
  end

  describe "SubmitMergeDomain — submit entity" do
    test "submit map carries the three button labels" do
      submit = FormInfo.submit(SubmitMergeDomain)
      assert is_map(submit)
      assert submit.create.label == "Domain Create"
      assert submit.update.label == "Domain Update"
      assert submit.cancel.label == "Domain Cancel"
    end

    test "submit position is :bottom" do
      submit = FormInfo.submit(SubmitMergeDomain)
      assert submit.position == :bottom
    end
  end

  describe "DomainDefaults section declaration" do
    alias MishkaGervaz.Form.Dsl.DomainDefaults

    test "section/0 returns a section named :form" do
      section = DomainDefaults.section()
      assert section.name == :form
    end

    test "section schema declares the inheritable top-level keys" do
      section = DomainDefaults.section()
      keys = Keyword.keys(section.schema)

      for key <- [
            :ui_adapter,
            :ui_adapter_opts,
            :actor_key,
            :master_check,
            :template,
            :features
          ] do
        assert key in keys, "missing schema key: #{key}"
      end
    end

    test "section composes :actions, :theme, :layout sub-sections" do
      section = DomainDefaults.section()
      sub_names = Enum.map(section.sections, & &1.name)
      assert :actions in sub_names
      assert :theme in sub_names
      assert :layout in sub_names
    end

    test "actions sub-section declares create / update / read" do
      section = DomainDefaults.section()
      actions = Enum.find(section.sections, &(&1.name == :actions))
      keys = Keyword.keys(actions.schema)

      for key <- [:create, :update, :read] do
        assert key in keys, "missing actions key: #{key}"
      end
    end

    test "theme sub-section declares form_class / field_class / label_class / error_class / extra" do
      section = DomainDefaults.section()
      theme = Enum.find(section.sections, &(&1.name == :theme))
      keys = Keyword.keys(theme.schema)

      for key <- [:form_class, :field_class, :label_class, :error_class, :extra] do
        assert key in keys, "missing theme key: #{key}"
      end
    end

    test "layout sub-section declares navigation / persistence / columns / responsive" do
      section = DomainDefaults.section()
      layout = Enum.find(section.sections, &(&1.name == :layout))
      keys = Keyword.keys(layout.schema)

      for key <- [:navigation, :persistence, :columns, :responsive] do
        assert key in keys, "missing layout key: #{key}"
      end
    end

    test "section embeds the same Submit entity used at resource level" do
      section = DomainDefaults.section()
      [submit] = section.entities
      assert submit.name == :submit
      assert submit.target == MishkaGervaz.Form.Entities.Submit
    end
  end
end

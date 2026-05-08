defmodule MishkaGervaz.Info.DomainFormInfoTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Domain.Info.Form` accessors.

  The existing `domain_info_test.exs` exercises only the table-side of
  `DomainInfo`. Form-side domain accessors had zero direct value
  assertions — this file fills that gap.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Domain.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Domain
  alias MishkaGervaz.Test.Resources.SubmitMergeDomain

  defmodule BareDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  describe "config/1" do
    test "returns the persisted domain config map on Test.Domain" do
      config = FormInfo.config(Domain)
      assert is_map(config)
      assert Map.has_key?(config, :form)
    end

    test "returns nil for a domain without mishka_gervaz" do
      assert FormInfo.config(BareDomain) == nil
    end
  end

  describe "defaults/1" do
    test "returns the form defaults map on Test.Domain" do
      defaults = FormInfo.defaults(Domain)
      assert is_map(defaults)
      assert defaults.actor_key == :current_user
      assert defaults.template == MishkaGervaz.Form.Templates.Standard
      assert defaults.features == :all
      assert defaults.ui_adapter == MishkaGervaz.UIAdapters.Tailwind
    end

    test "returns %{} for a domain without mishka_gervaz" do
      assert FormInfo.defaults(BareDomain) == %{}
    end
  end

  describe "ui_adapter/1" do
    test "returns the Tailwind adapter on Test.Domain" do
      assert FormInfo.ui_adapter(Domain) == MishkaGervaz.UIAdapters.Tailwind
    end

    test "returns nil for a domain that does not configure it" do
      assert FormInfo.ui_adapter(BareDomain) == nil
    end
  end

  describe "ui_adapter_opts/1" do
    test "defaults to [] when no opts set" do
      assert FormInfo.ui_adapter_opts(Domain) == []
      assert FormInfo.ui_adapter_opts(BareDomain) == []
    end
  end

  describe "actor_key/1" do
    test "returns the configured actor on Test.Domain" do
      assert FormInfo.actor_key(Domain) == :current_user
    end

    test "defaults to :current_user when not configured" do
      assert FormInfo.actor_key(BareDomain) == :current_user
    end
  end

  describe "master_check/1" do
    test "returns a function/1 on Test.Domain" do
      check = FormInfo.master_check(Domain)
      assert is_function(check, 1)
      assert check.(%{role: :admin}) == true
      assert check.(%{role: :user}) == false
    end

    test "returns nil when not configured" do
      assert FormInfo.master_check(BareDomain) == nil
    end
  end

  describe "actions/1" do
    test "returns the configured action map on Test.Domain" do
      actions = FormInfo.actions(Domain)
      assert is_map(actions)
      assert actions.create == {:master_create, :create}
      assert actions.update == {:master_update, :update}
      assert actions.read == {:master_get, :read}
    end

    test "returns nil when not configured" do
      assert FormInfo.actions(BareDomain) == nil
    end
  end

  describe "theme/1" do
    test "returns nil on Test.Domain (no theme configured)" do
      assert FormInfo.theme(Domain) == nil
    end

    test "returns nil for BareDomain" do
      assert FormInfo.theme(BareDomain) == nil
    end
  end

  describe "layout/1" do
    test "returns the layout map on Test.Domain (responsive: true)" do
      layout = FormInfo.layout(Domain)
      assert is_map(layout)
      assert layout.responsive == true
    end

    test "returns nil for BareDomain" do
      assert FormInfo.layout(BareDomain) == nil
    end
  end

  describe "template/1" do
    test "returns the configured template on Test.Domain" do
      assert FormInfo.template(Domain) == MishkaGervaz.Form.Templates.Standard
    end

    test "returns nil for BareDomain" do
      assert FormInfo.template(BareDomain) == nil
    end
  end

  describe "features/1" do
    test "returns :all on Test.Domain" do
      assert FormInfo.features(Domain) == :all
    end

    test "returns nil for BareDomain" do
      assert FormInfo.features(BareDomain) == nil
    end
  end

  describe "submit/1" do
    test "returns the populated submit map on SubmitMergeDomain" do
      submit = FormInfo.submit(SubmitMergeDomain)
      assert is_map(submit)
      assert submit.create.label == "Domain Create"
      assert submit.update.label == "Domain Update"
      assert submit.cancel.label == "Domain Cancel"
      assert submit.position == :bottom
    end

    test "returns the populated submit map on Test.Domain" do
      submit = FormInfo.submit(Domain)
      assert is_map(submit)
      assert submit.create.label == "Save"
      assert submit.update.label == "Save Changes"
      assert submit.cancel.label == "Cancel"
    end

    test "returns nil for BareDomain" do
      assert FormInfo.submit(BareDomain) == nil
    end
  end
end

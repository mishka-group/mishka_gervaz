defmodule MishkaGervaz.Form.Transformers.BuildDomainConfigTest do
  @moduledoc """
  Tests for the form-specific BuildDomainConfig transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.DomainInfo
  alias MishkaGervaz.Test.Domain

  describe "domain config structure" do
    test "domain config is persisted" do
      config = DomainInfo.domain_config(Domain)
      assert config != nil
      assert is_map(config)
    end

    test "config contains form section" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config, :form)
      assert is_map(config.form)
    end
  end

  describe "form section top-level" do
    test "form section contains ui_adapter" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :ui_adapter)
      assert config.form.ui_adapter == MishkaGervaz.UIAdapters.Tailwind
    end

    test "form section contains actor_key" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :actor_key)
      assert config.form.actor_key == :current_user
    end

    test "form section contains master_check" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :master_check)
      assert is_function(config.form.master_check)
    end

    test "form section contains template" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :template)
      assert config.form.template == MishkaGervaz.Form.Templates.Standard
    end

    test "form section contains features" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :features)
      assert config.form.features == :all
    end
  end

  describe "form actions" do
    test "form section contains actions" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :actions)
      assert is_map(config.form.actions)
    end

    test "create action has expected default tuple" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.actions.create == {:master_create, :create}
    end

    test "update action has expected default tuple" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.actions.update == {:master_update, :update}
    end

    test "read action has expected default tuple" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.actions.read == {:master_get, :read}
    end
  end

  describe "form theme" do
    test "theme is nil when not defined in domain" do
      config = DomainInfo.domain_config(Domain)
      assert config.form[:theme] == nil
    end
  end

  describe "form layout" do
    test "form section contains layout" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :layout)
      assert is_map(config.form.layout)
    end

    test "layout contains responsive" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form.layout, :responsive)
      assert config.form.layout.responsive == true
    end

    test "layout contains columns default" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form.layout, :columns)
    end

    test "layout contains navigation default" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form.layout, :navigation)
    end

    test "layout contains persistence default" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form.layout, :persistence)
    end
  end

  describe "form submit" do
    test "form section contains submit" do
      config = DomainInfo.domain_config(Domain)
      assert Map.has_key?(config.form, :submit)
      assert is_map(config.form.submit)
    end

    test "submit contains create_label" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.submit.create_label == "Save"
    end

    test "submit contains update_label" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.submit.update_label == "Save Changes"
    end

    test "submit contains position" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.submit.position == :bottom
    end

    test "submit contains cancel_label with default" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.submit.cancel_label == "Cancel"
    end

    test "submit contains show_cancel with default" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.submit.show_cancel == true
    end
  end

  describe "test domain specific values" do
    test "test domain has expected actor_key" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.actor_key == :current_user
    end

    test "test domain has expected template" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.template == MishkaGervaz.Form.Templates.Standard
    end

    test "test domain has expected features" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.features == :all
    end

    test "test domain has expected ui_adapter" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.ui_adapter == MishkaGervaz.UIAdapters.Tailwind
    end

    test "test domain has expected submit labels" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.submit.create_label == "Save"
      assert config.form.submit.update_label == "Save Changes"
    end

    test "test domain has expected layout responsive" do
      config = DomainInfo.domain_config(Domain)
      assert config.form.layout.responsive == true
    end
  end

  describe "optional sections" do
    test "theme is nil when not defined" do
      config = DomainInfo.domain_config(Domain)
      assert config.form[:theme] == nil
    end
  end
end

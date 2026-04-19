defmodule MishkaGervaz.Form.Types.Field.PasswordTest do
  @moduledoc """
  Tests for the password field type, type registry, and DSL compilation.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Password
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.PasswordForm

  describe "type module behaviour" do
    test "render returns assigns unchanged" do
      assigns = %{some: :data}
      assert Password.render(assigns, %{}) == assigns
    end

    test "validate accepts a string" do
      assert {:ok, "secret123"} = Password.validate("secret123", %{})
    end

    test "validate accepts nil" do
      assert {:ok, nil} = Password.validate(nil, %{})
    end

    test "validate accepts empty string" do
      assert {:ok, ""} = Password.validate("", %{})
    end

    test "parse_params returns value unchanged" do
      assert "mypassword" = Password.parse_params("mypassword", %{})
    end

    test "parse_params returns nil unchanged" do
      assert nil == Password.parse_params(nil, %{})
    end

    test "sanitize trims whitespace" do
      assert "secret" = Password.sanitize("  secret  ", %{})
    end

    test "sanitize returns non-binary unchanged" do
      assert nil == Password.sanitize(nil, %{})
    end

    test "default_ui returns password type" do
      assert %{type: :password} = Password.default_ui()
    end
  end

  describe "type registry" do
    test "password resolves to Password module" do
      assert MishkaGervaz.Form.Types.Field.get_or_passthrough(:password) == Password
    end

    test "password is a builtin type" do
      assert MishkaGervaz.Form.Types.Field.builtin?(:password)
    end
  end

  describe "DSL compilation with explicit :password" do
    test "password field has type :password" do
      field = FormInfo.field(PasswordForm, :password)
      assert field.type == :password
    end

    test "password field has type_module set" do
      field = FormInfo.field(PasswordForm, :password)
      assert field.type_module == Password
    end

    test "password field is virtual" do
      field = FormInfo.field(PasswordForm, :password)
      assert field.virtual == true
    end

    test "password field has UI label" do
      field = FormInfo.field(PasswordForm, :password)
      assert field.ui.label == "Password"
    end

    test "password field has UI placeholder" do
      field = FormInfo.field(PasswordForm, :password)
      assert field.ui.placeholder == "Enter password"
    end

    test "password field has UI autocomplete" do
      field = FormInfo.field(PasswordForm, :password)
      assert field.ui.autocomplete == "new-password"
    end

    test "password_confirmation field has type :password" do
      field = FormInfo.field(PasswordForm, :password_confirmation)
      assert field.type == :password
    end

    test "password_confirmation field has type_module set" do
      field = FormInfo.field(PasswordForm, :password_confirmation)
      assert field.type_module == Password
    end

    test "password_confirmation field is virtual" do
      field = FormInfo.field(PasswordForm, :password_confirmation)
      assert field.virtual == true
    end

    test "password_confirmation field has UI label" do
      field = FormInfo.field(PasswordForm, :password_confirmation)
      assert field.ui.label == "Confirm Password"
    end
  end

  describe "group resolution" do
    test "password fields appear in credentials group" do
      groups = FormInfo.groups(PasswordForm)
      credentials = Enum.find(groups, &(&1.name == :credentials))
      assert credentials != nil

      assert :email in credentials.fields
      assert :password in credentials.fields
      assert :password_confirmation in credentials.fields
    end

    test "credentials group has 2 columns" do
      groups = FormInfo.groups(PasswordForm)
      credentials = Enum.find(groups, &(&1.name == :credentials))
      assert credentials.ui.columns == 2
    end
  end

  describe "field count" do
    test "PasswordForm has 3 fields" do
      fields = FormInfo.fields(PasswordForm)
      assert length(fields) == 3
    end
  end
end

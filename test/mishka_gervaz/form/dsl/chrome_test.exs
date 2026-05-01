defmodule MishkaGervaz.Form.DSL.ChromeTest do
  @moduledoc """
  Tests for the chrome entities (header, footer, notice) inside the form
  layout DSL section.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ChromeForm

  describe "header" do
    test "compiled into layout" do
      assert %{} = FormInfo.header(ChromeForm)
    end

    test "title is set" do
      assert FormInfo.header(ChromeForm).title == "Account Permissions"
    end

    test "description is set" do
      assert FormInfo.header(ChromeForm).description ==
               "Configure what this account can access."
    end

    test "icon is set" do
      assert FormInfo.header(ChromeForm).icon == "hero-shield-check"
    end

    test "class is set" do
      assert FormInfo.header(ChromeForm).class == "mb-6"
    end

    test "visible defaults to true" do
      assert FormInfo.header(ChromeForm).visible == true
    end

    test "restricted defaults to false" do
      assert FormInfo.header(ChromeForm).restricted == false
    end
  end

  describe "footer" do
    test "compiled into layout" do
      assert %{} = FormInfo.footer(ChromeForm)
    end

    test "content is callable" do
      content = FormInfo.footer(ChromeForm).content
      assert is_function(content, 1)
      assert content.(%{}) == "Last updated externally"
    end

    test "class is set" do
      assert FormInfo.footer(ChromeForm).class == "mt-4 text-xs"
    end
  end

  describe "notices/1" do
    test "returns all notices in declaration order" do
      names = ChromeForm |> FormInfo.notices() |> Enum.map(& &1.name)

      assert names == [
               :read_only_banner,
               :validation_summary,
               :after_basic_note,
               :master_only
             ]
    end
  end

  describe "notice properties" do
    test "position atom" do
      assert FormInfo.notice(ChromeForm, :read_only_banner).position == :before_fields
      assert FormInfo.notice(ChromeForm, :validation_summary).position == :form_top
      assert FormInfo.notice(ChromeForm, :master_only).position == :before_submit
    end

    test "position tuple {:after_group, :basic}" do
      assert FormInfo.notice(ChromeForm, :after_basic_note).position == {:after_group, :basic}
    end

    test "type" do
      assert FormInfo.notice(ChromeForm, :read_only_banner).type == :warning
      assert FormInfo.notice(ChromeForm, :validation_summary).type == :error
      assert FormInfo.notice(ChromeForm, :after_basic_note).type == :info
      assert FormInfo.notice(ChromeForm, :master_only).type == :neutral
    end

    test "title and content" do
      n = FormInfo.notice(ChromeForm, :read_only_banner)
      assert n.title == "Read-Only Access"
      assert n.content == "Your role can view but not modify these settings."
    end

    test "icon" do
      assert FormInfo.notice(ChromeForm, :read_only_banner).icon == "hero-lock-closed"
    end

    test "dismissible defaults to false" do
      assert FormInfo.notice(ChromeForm, :read_only_banner).dismissible == false
    end

    test "bind_to is :validation when set" do
      assert FormInfo.notice(ChromeForm, :validation_summary).bind_to == :validation
    end

    test "bind_to is nil by default" do
      assert FormInfo.notice(ChromeForm, :read_only_banner).bind_to == nil
    end

    test "visible function is preserved" do
      n = FormInfo.notice(ChromeForm, :read_only_banner)
      assert is_function(n.visible, 1)
      assert n.visible.(%{master_user?: false}) == true
      assert n.visible.(%{master_user?: true}) == false
    end

    test "restricted is true for master-only notice" do
      assert FormInfo.notice(ChromeForm, :master_only).restricted == true
    end

    test "ui block class is captured" do
      ui = FormInfo.notice(ChromeForm, :read_only_banner).ui
      assert ui.class == "border-amber-300"
    end
  end

  describe "notices_at/2" do
    test "filters by atom position" do
      assert [%{name: :validation_summary}] = FormInfo.notices_at(ChromeForm, :form_top)
      assert [%{name: :read_only_banner}] = FormInfo.notices_at(ChromeForm, :before_fields)
      assert [%{name: :master_only}] = FormInfo.notices_at(ChromeForm, :before_submit)
    end

    test "filters by tuple position" do
      assert [%{name: :after_basic_note}] =
               FormInfo.notices_at(ChromeForm, {:after_group, :basic})
    end

    test "returns empty list for unknown position" do
      assert FormInfo.notices_at(ChromeForm, :form_bottom) == []
    end
  end

  describe "Notice.validate_position/1" do
    alias MishkaGervaz.Form.Entities.Notice

    test "accepts valid atom positions" do
      for atom <- Notice.valid_position_atoms() do
        assert Notice.validate_position(atom) == :ok
      end
    end

    test "accepts {:before_group, atom}" do
      assert Notice.validate_position({:before_group, :basic}) == :ok
    end

    test "accepts {:after_group, atom}" do
      assert Notice.validate_position({:after_group, :basic}) == :ok
    end

    test "rejects unknown atom" do
      assert {:error, _} = Notice.validate_position(:nope)
    end

    test "rejects malformed tuple" do
      assert {:error, _} = Notice.validate_position({:before_group, "string"})
      assert {:error, _} = Notice.validate_position({:wrong, :basic})
    end
  end
end

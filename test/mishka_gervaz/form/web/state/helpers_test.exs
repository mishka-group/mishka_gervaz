defmodule MishkaGervaz.Form.Web.State.HelpersTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Form.Web.State.Helpers`.

  These pin the helper contracts that the macro and `Form.Web.Live` both
  depend on. Integration tests in `state_test.exs` exercise the same
  helpers transitively but a regression in any single clause would only
  show up via a hard-to-localize symptom there.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.State.Helpers

  describe "generate_stream_name/1" do
    test "derives `<snake_module>_form_stream` atom" do
      assert Helpers.generate_stream_name(MishkaGervaz.Test.Resources.FormPost) ==
               :form_post_form_stream
    end
  end

  describe "get_layout_mode/1" do
    test "returns valid mode atoms" do
      for mode <- [:standard, :wizard, :tabs] do
        assert Helpers.get_layout_mode(%{layout: %{mode: mode}}) == mode
      end
    end

    test "defaults to :standard for unknown atom" do
      assert Helpers.get_layout_mode(%{layout: %{mode: :gibberish}}) == :standard
    end

    test "defaults to :standard when layout is missing" do
      assert Helpers.get_layout_mode(%{}) == :standard
    end

    test "defaults to :standard when layout has no :mode" do
      assert Helpers.get_layout_mode(%{layout: %{}}) == :standard
    end
  end

  describe "get_layout_columns/1" do
    test "returns valid column counts" do
      for cols <- 1..4 do
        assert Helpers.get_layout_columns(%{layout: %{columns: cols}}) == cols
      end
    end

    test "defaults to 1 for out-of-range" do
      assert Helpers.get_layout_columns(%{layout: %{columns: 5}}) == 1
      assert Helpers.get_layout_columns(%{layout: %{columns: 0}}) == 1
    end

    test "defaults to 1 when missing" do
      assert Helpers.get_layout_columns(%{}) == 1
    end
  end

  describe "get_layout_navigation/1" do
    test "returns valid navigation atoms" do
      assert Helpers.get_layout_navigation(%{layout: %{navigation: :sequential}}) ==
               :sequential

      assert Helpers.get_layout_navigation(%{layout: %{navigation: :free}}) == :free
    end

    test "defaults to :sequential for unknown" do
      assert Helpers.get_layout_navigation(%{layout: %{navigation: :random}}) == :sequential
      assert Helpers.get_layout_navigation(%{}) == :sequential
    end
  end

  describe "get_uploads/1" do
    test "returns the uploads list" do
      uploads = [%{name: :avatar}, %{name: :cover}]
      assert Helpers.get_uploads(%{uploads: uploads}) == uploads
    end

    test "defaults to []" do
      assert Helpers.get_uploads(%{}) == []
      assert Helpers.get_uploads(%{uploads: nil}) == []
      assert Helpers.get_uploads(%{uploads: %{}}) == []
    end
  end

  describe "get_header/1, get_footer/1" do
    test "returns map when present" do
      assert Helpers.get_header(%{layout: %{header: %{title: "T"}}}) == %{title: "T"}
      assert Helpers.get_footer(%{layout: %{footer: %{content: "C"}}}) == %{content: "C"}
    end

    test "returns nil when absent or non-map" do
      assert Helpers.get_header(%{}) == nil
      assert Helpers.get_footer(%{}) == nil
      assert Helpers.get_header(%{layout: %{header: nil}}) == nil
      assert Helpers.get_footer(%{layout: %{footer: "string"}}) == nil
    end
  end

  describe "get_notices/1" do
    test "returns notices list" do
      notices = [%{name: :one}, %{name: :two}]
      assert Helpers.get_notices(%{layout: %{notices: notices}}) == notices
    end

    test "defaults to []" do
      assert Helpers.get_notices(%{}) == []
      assert Helpers.get_notices(%{layout: %{}}) == []
    end
  end

  describe "get_submit/1" do
    test "returns the submit map when present" do
      submit = %{create: %{label: "Go"}, position: :top}
      assert Helpers.get_submit(%{submit: submit}) == submit
    end

    test "default has create/update/cancel/position/ui keys" do
      default = Helpers.get_submit(%{})
      assert is_map(default.create)
      assert is_map(default.update)
      assert is_map(default.cancel)
      assert default.position == :bottom
      assert default.ui == nil
    end
  end

  describe "get_hooks/1" do
    test "returns the hooks map" do
      hooks = %{js: %{on_init: fn -> %Phoenix.LiveView.JS{} end}}
      assert Helpers.get_hooks(%{hooks: hooks}) == hooks
    end

    test "defaults to %{}" do
      assert Helpers.get_hooks(%{}) == %{}
    end
  end

  describe "groups_for_step/3" do
    setup do
      groups = [%{name: :general, fields: [:title]}, %{name: :advanced, fields: [:tags]}]
      steps = [%{name: :basics, groups: [:general]}, %{name: :more, groups: [:advanced]}]
      %{groups: groups, steps: steps}
    end

    test "filters groups by step membership", %{groups: groups, steps: steps} do
      assert [%{name: :general}] = Helpers.groups_for_step(groups, steps, :basics)
      assert [%{name: :advanced}] = Helpers.groups_for_step(groups, steps, :more)
    end

    test "returns all groups when step name not found", %{groups: groups, steps: steps} do
      assert Helpers.groups_for_step(groups, steps, :nonexistent) == groups
    end

    test "returns all groups when step has no :groups list", %{groups: groups} do
      steps = [%{name: :weird}]
      assert Helpers.groups_for_step(groups, steps, :weird) == groups
    end
  end

  describe "resolve_access/1" do
    test "always returns Access.Default for now" do
      assert Helpers.resolve_access(SomeModule) ==
               MishkaGervaz.Form.Web.State.Access.Default
    end
  end

  describe "mode_allowed?/3" do
    test "nil source allows everything" do
      assert Helpers.mode_allowed?(nil, :create, %{master_user?: false})
    end

    test "no constraints allows everything" do
      assert Helpers.mode_allowed?(%{}, :create, %{master_user?: false})
    end

    test "restricted: true is master-gated" do
      source = %{restricted: true}
      assert Helpers.mode_allowed?(source, :create, %{master_user?: true})
      refute Helpers.mode_allowed?(source, :create, %{master_user?: false})
    end

    test "restricted: fn — function is the final word, master gate not applied" do
      source = %{restricted: fn _state -> true end}
      refute Helpers.mode_allowed?(source, :create, %{master_user?: true})
      refute Helpers.mode_allowed?(source, :create, %{master_user?: false})

      source = %{restricted: fn _state -> false end}
      assert Helpers.mode_allowed?(source, :create, %{master_user?: true})
      assert Helpers.mode_allowed?(source, :create, %{master_user?: false})
    end

    test "access_gate function decides" do
      source = %{access_gate: fn _mode, state -> state.role == :admin end}
      assert Helpers.mode_allowed?(source, :create, %{role: :admin, master_user?: false})
      refute Helpers.mode_allowed?(source, :create, %{role: :guest, master_user?: true})
    end

    test "access_rules per-mode :restricted is master-gated" do
      source = %{access_rules: %{create: %{restricted: true}}}
      assert Helpers.mode_allowed?(source, :create, %{master_user?: true})
      refute Helpers.mode_allowed?(source, :create, %{master_user?: false})
    end

    test "access_rules per-mode :condition function" do
      source = %{access_rules: %{update: %{condition: fn state -> state.dirty? end}}}
      assert Helpers.mode_allowed?(source, :update, %{master_user?: false, dirty?: true})
      refute Helpers.mode_allowed?(source, :update, %{master_user?: true, dirty?: false})
    end

    test "access_rules with no matching rule for mode falls through to other branches" do
      source = %{access_rules: %{create: %{restricted: true}}, restricted: true}
      assert Helpers.mode_allowed?(source, :update, %{master_user?: true})
      refute Helpers.mode_allowed?(source, :update, %{master_user?: false})
    end
  end
end

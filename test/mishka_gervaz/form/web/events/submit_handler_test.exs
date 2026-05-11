defmodule MishkaGervaz.Form.Web.Events.SubmitHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.SubmitHandler` top-level
  helpers (the pure data-shape ones extracted out of the macro).

  `submit/3`, `transform_params/2`, `after_save/3` mutate sockets and
  call `AshPhoenix.Form.submit/2` — exercised via integration in
  `events_test.exs`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.SubmitHandler

  describe "format_form_errors/1" do
    test "groups errors by field with placeholder interpolation" do
      form = %Phoenix.HTML.Form{
        errors: [
          {:title, {"can't be blank", []}},
          {:title, {"is too short", []}},
          {:age, {"must be at least %{min}", [min: 18]}}
        ]
      }

      result = SubmitHandler.format_form_errors(form)

      assert result[:title] == ["can't be blank", "is too short"]
      assert result[:age] == ["must be at least 18"]
    end

    test "returns %{} for an empty errors list" do
      assert SubmitHandler.format_form_errors(%Phoenix.HTML.Form{errors: []}) == %{}
    end
  end

  describe "extract_form_level_errors/2" do
    test "returns errors not associated with any known field name" do
      form = %Phoenix.HTML.Form{
        errors: [
          {:title, {"is required", []}},
          {nil, {"some global problem", []}},
          {:body, {"is required", []}}
        ]
      }

      field_names = MapSet.new([:title, :body])
      assert SubmitHandler.extract_form_level_errors(form, field_names) == ["some global problem"]
    end

    test "returns [] when all errors map to known fields" do
      form = %Phoenix.HTML.Form{
        errors: [{:title, {"is required", []}}]
      }

      assert SubmitHandler.extract_form_level_errors(form, MapSet.new([:title])) == []
    end

    test "interpolates placeholders" do
      form = %Phoenix.HTML.Form{
        errors: [{:_form, {"too many %{kind} values", [kind: "tag"]}}]
      }

      assert SubmitHandler.extract_form_level_errors(form, MapSet.new()) ==
               ["too many tag values"]
    end
  end

  describe "merge_defaults/2" do
    test "fills missing keys in :create mode" do
      state = %{mode: :create, defaults: %{site_id: "uuid", workspace_id: "ws"}}
      params = %{"title" => "Hi"}

      assert SubmitHandler.merge_defaults(state, params) ==
               %{"title" => "Hi", "site_id" => "uuid", "workspace_id" => "ws"}
    end

    test "doesn't overwrite existing keys" do
      state = %{mode: :create, defaults: %{site_id: "default"}}

      assert SubmitHandler.merge_defaults(state, %{"site_id" => "user-set"}) ==
               %{"site_id" => "user-set"}
    end

    test "treats nil/empty-string as missing and overwrites" do
      state = %{mode: :create, defaults: %{site_id: "default"}}

      assert SubmitHandler.merge_defaults(state, %{"site_id" => ""}) ==
               %{"site_id" => "default"}

      assert SubmitHandler.merge_defaults(state, %{"site_id" => nil}) ==
               %{"site_id" => "default"}
    end

    test "no-op when not in :create mode" do
      state = %{mode: :update, defaults: %{site_id: "default"}}
      assert SubmitHandler.merge_defaults(state, %{}) == %{}
    end

    test "no-op when defaults is empty / not a map" do
      assert SubmitHandler.merge_defaults(%{mode: :create, defaults: %{}}, %{"a" => 1}) ==
               %{"a" => 1}

      assert SubmitHandler.merge_defaults(%{mode: :create, defaults: nil}, %{"a" => 1}) ==
               %{"a" => 1}
    end
  end

  describe "drop_protected_fields/2" do
    test "drops fields where restricted is true and user is not master" do
      state = %{
        master_user?: false,
        static: %{fields: [%{name: :secret, restricted: true}, %{name: :title}]}
      }

      assert SubmitHandler.drop_protected_fields(state, %{
               "secret" => "redacted",
               "title" => "Hi"
             }) == %{"title" => "Hi"}
    end

    test "keeps restricted fields for master users" do
      state = %{
        master_user?: true,
        static: %{fields: [%{name: :secret, restricted: true}]}
      }

      assert SubmitHandler.drop_protected_fields(state, %{"secret" => "kept"}) ==
               %{"secret" => "kept"}
    end

    test "drops readonly fields" do
      state = %{
        master_user?: true,
        static: %{fields: [%{name: :id, readonly: true}]}
      }

      assert SubmitHandler.drop_protected_fields(state, %{"id" => "x"}) == %{}
    end

    test "passes through fields without restricted/readonly" do
      state = %{master_user?: false, static: %{fields: [%{name: :title}]}}

      assert SubmitHandler.drop_protected_fields(state, %{"title" => "Hi"}) ==
               %{"title" => "Hi"}
    end
  end

  describe "field_restricted?/2" do
    test "true when restricted=true and user is not master" do
      assert SubmitHandler.field_restricted?(%{restricted: true}, %{master_user?: false})
    end

    test "false when restricted=true but user is master" do
      refute SubmitHandler.field_restricted?(%{restricted: true}, %{master_user?: true})
    end

    test "function form: returns NOT of fn(state)" do
      assert SubmitHandler.field_restricted?(%{restricted: fn _s -> false end}, %{})
      refute SubmitHandler.field_restricted?(%{restricted: fn _s -> true end}, %{})
    end

    test "false when no :restricted key" do
      refute SubmitHandler.field_restricted?(%{}, %{master_user?: false})
    end
  end

  describe "field_readonly?/2" do
    test "true when readonly=true" do
      assert SubmitHandler.field_readonly?(%{readonly: true}, %{})
    end

    test "calls function form" do
      assert SubmitHandler.field_readonly?(%{readonly: fn _s -> true end}, %{})
      refute SubmitHandler.field_readonly?(%{readonly: fn _s -> false end}, %{})
    end

    test "false when no :readonly or readonly=false" do
      refute SubmitHandler.field_readonly?(%{}, %{})
      refute SubmitHandler.field_readonly?(%{readonly: false}, %{})
    end
  end
end

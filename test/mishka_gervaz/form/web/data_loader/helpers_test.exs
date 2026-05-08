defmodule MishkaGervaz.Form.Web.DataLoader.HelpersTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Form.Web.DataLoader.Helpers`.

  These pin every helper that was moved out of the `__using__` macro so a
  regression in any one of them surfaces here, not via a hard-to-localize
  symptom in `data_loader_test.exs`.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.DataLoader.Helpers

  defp state_with(overrides \\ []) do
    static_overrides = Keyword.get(overrides, :static, [])

    static =
      Map.merge(
        %{fields: [], uploads: [], hooks: %{}, resource: nil},
        Map.new(static_overrides)
      )

    base = %{
      static: static,
      defaults: nil,
      field_values: %{},
      relation_options: %{},
      master_user?: true,
      current_user: nil
    }

    Enum.reduce(overrides, base, fn
      {:static, _}, acc -> acc
      {k, v}, acc -> Map.put(acc, k, v)
    end)
  end

  describe "find_field/2" do
    test "returns the field map when found" do
      state = state_with(static: [fields: [%{name: :title}, %{name: :body}]])
      assert Helpers.find_field(state, :body) == %{name: :body}
    end

    test "returns nil when not found" do
      state = state_with(static: [fields: [%{name: :title}]])
      assert Helpers.find_field(state, :ghost) == nil
    end

    test "returns nil when no fields" do
      assert Helpers.find_field(state_with(), :anything) == nil
    end
  end

  describe "extract_existing_files/2" do
    test "returns %{} when uploads is empty" do
      state = state_with(static: [uploads: []])
      assert Helpers.extract_existing_files(state, %{}) == %{}
    end

    test "returns %{} when form has no record data" do
      state = state_with(static: [uploads: [%{name: :avatar}]])
      assert Helpers.extract_existing_files(state, %{}) == %{}
    end

    test "extracts from record using upload name as field key by default" do
      state = state_with(static: [uploads: [%{name: :cover}]])
      form = %{source: %{source: %{data: %{cover: "image.png"}}}}

      assert Helpers.extract_existing_files(state, form) == %{
               cover: [%{filename: "image.png"}]
             }
    end

    test "uses :field option when set" do
      state = state_with(static: [uploads: [%{name: :avatar, field: :photo_url}]])
      form = %{source: %{source: %{data: %{photo_url: "p.jpg"}}}}

      assert Helpers.extract_existing_files(state, form) == %{
               avatar: [%{filename: "p.jpg"}]
             }
    end

    test "uses :existing function when set" do
      state =
        state_with(
          static: [
            uploads: [%{name: :files, existing: fn record -> record.files end}]
          ]
        )

      form = %{source: %{source: %{data: %{files: ["a.txt", "b.txt"]}}}}

      assert Helpers.extract_existing_files(state, form) == %{
               files: [%{filename: "a.txt"}, %{filename: "b.txt"}]
             }
    end
  end

  describe "normalize_file_list/1" do
    test "nil → []" do
      assert Helpers.normalize_file_list(nil) == []
    end

    test "string → [%{filename: …}]" do
      assert Helpers.normalize_file_list("foo.png") == [%{filename: "foo.png"}]
    end

    test "list of strings" do
      assert Helpers.normalize_file_list(["a.txt", "b.txt"]) == [
               %{filename: "a.txt"},
               %{filename: "b.txt"}
             ]
    end

    test "single map → wrapped in list" do
      assert Helpers.normalize_file_list(%{filename: "x.png"}) == [%{filename: "x.png"}]
    end

    test "non-conforming → []" do
      assert Helpers.normalize_file_list(:weird) == []
      assert Helpers.normalize_file_list(123) == []
    end
  end

  describe "normalize_file_info/1" do
    test "atom-keyed :filename passes through" do
      assert Helpers.normalize_file_info(%{filename: "f.png"}) == %{filename: "f.png"}
    end

    test "atom-keyed :name → adds :filename" do
      result = Helpers.normalize_file_info(%{name: "n.png", id: 1})
      assert result.filename == "n.png"
      assert result.name == "n.png"
      assert result.id == 1
    end

    test "string-keyed \"filename\" → atom-keyed map" do
      assert Helpers.normalize_file_info(%{"filename" => "f.png", "id" => "u-1"}) ==
               %{filename: "f.png", id: "u-1"}
    end

    test "string-keyed \"name\" → atom-keyed map" do
      assert Helpers.normalize_file_info(%{"name" => "n.png", "id" => "u-2"}) ==
               %{filename: "n.png", id: "u-2"}
    end

    test "plain string → %{filename: …}" do
      assert Helpers.normalize_file_info("plain.txt") == %{filename: "plain.txt"}
    end

    test "fallback for unknown shape" do
      result = Helpers.normalize_file_info(123)
      assert is_binary(result.filename)
    end
  end

  describe "extract_dependency_values/2" do
    test "returns %{} when form has no record" do
      state = state_with(static: [fields: [%{name: :title, depends_on: nil, type: :text}]])
      assert Helpers.extract_dependency_values(state, %{}) == %{}

      assert Helpers.extract_dependency_values(state, %{source: %{source: %{data: nil}}}) ==
               %{}
    end

    test "includes :depends_on values from record" do
      state =
        state_with(
          static: [
            fields: [
              %{name: :site_id, depends_on: nil, type: :relation},
              %{name: :tag, depends_on: :site_id, type: :text}
            ]
          ]
        )

      form = %{source: %{source: %{data: %{site_id: "uuid-1", tag: "elixir"}}}}

      result = Helpers.extract_dependency_values(state, form)

      assert result[:site_id] == "uuid-1"
    end

    test "includes :relation field names" do
      state =
        state_with(
          static: [
            fields: [%{name: :category_id, depends_on: nil, type: :relation}]
          ]
        )

      form = %{source: %{source: %{data: %{category_id: "cat-1"}}}}
      result = Helpers.extract_dependency_values(state, form)

      assert result[:category_id] == "cat-1"
    end

    test "applies :derive_value when raw value is nil" do
      derive = fn record -> "derived-from-#{record.id}" end

      state =
        state_with(
          static: [
            fields: [
              %{name: :workspace_id, depends_on: nil, type: :relation, derive_value: derive}
            ]
          ]
        )

      form = %{source: %{source: %{data: %{id: 42, workspace_id: nil}}}}
      result = Helpers.extract_dependency_values(state, form)

      assert result[:workspace_id] == "derived-from-42"
    end

    test "rejects nil and empty-string values" do
      state =
        state_with(
          static: [
            fields: [
              %{name: :a, depends_on: nil, type: :relation},
              %{name: :b, depends_on: nil, type: :relation}
            ]
          ]
        )

      form = %{source: %{source: %{data: %{a: nil, b: ""}}}}
      assert Helpers.extract_dependency_values(state, form) == %{}
    end
  end

  describe "extract_defaults_to_field_values/1" do
    test "returns %{} when defaults is nil" do
      assert Helpers.extract_defaults_to_field_values(state_with()) == %{}
    end

    test "returns %{} when defaults is %{}" do
      assert Helpers.extract_defaults_to_field_values(state_with(defaults: %{})) == %{}
    end

    test "passes through non-empty defaults" do
      result =
        Helpers.extract_defaults_to_field_values(state_with(defaults: %{site_id: "s-1"}))

      assert result == %{site_id: "s-1"}
    end

    test "rejects nil and empty-string entries" do
      result =
        Helpers.extract_defaults_to_field_values(
          state_with(defaults: %{a: 1, b: nil, c: "", d: "ok"})
        )

      assert result == %{a: 1, d: "ok"}
    end
  end

  describe "run_on_init_hook/2" do
    test "passes form through when no hook" do
      form = %Phoenix.HTML.Form{name: "f"}
      assert Helpers.run_on_init_hook(state_with(), form) == form
    end

    test "applies hook returning a new form" do
      modified = %Phoenix.HTML.Form{name: "modified"}
      hook = fn _form, _state -> modified end
      state = state_with(static: [hooks: %{on_init: hook}])

      assert Helpers.run_on_init_hook(state, %Phoenix.HTML.Form{name: "orig"}) == modified
    end

    test "ignores non-form return value" do
      hook = fn _form, _state -> :gibberish end
      state = state_with(static: [hooks: %{on_init: hook}])
      orig = %Phoenix.HTML.Form{name: "orig"}

      assert Helpers.run_on_init_hook(state, orig) == orig
    end
  end

  describe "field_readonly?/2" do
    test "true when :readonly is true" do
      assert Helpers.field_readonly?(%{readonly: true}, %{})
    end

    test "false when :readonly is missing or false" do
      refute Helpers.field_readonly?(%{}, %{})
      refute Helpers.field_readonly?(%{readonly: false}, %{})
    end

    test "calls function when :readonly is a 1-arity fn" do
      assert Helpers.field_readonly?(%{readonly: fn _ -> true end}, %{})
      refute Helpers.field_readonly?(%{readonly: fn _ -> false end}, %{})
    end
  end

  describe "load_dependent_relations/3" do
    test "calls load_fn for each dependent relation field whose dep value is set" do
      state =
        state_with(
          static: [
            fields: [
              %{name: :country_id, depends_on: nil, type: :relation},
              %{name: :state_id, depends_on: :country_id, type: :relation},
              %{name: :ignored, depends_on: :nonexistent, type: :relation}
            ]
          ],
          field_values: %{country_id: "us"}
        )

      calls = :ets.new(:calls, [:public])

      load_fn = fn socket, _state, name ->
        :ets.insert(calls, {name})
        socket
      end

      Helpers.load_dependent_relations(:fake_socket, state, load_fn)
      results = :ets.tab2list(calls) |> Enum.map(&elem(&1, 0))

      assert results == [:state_id]
    end

    test "no-op when no dependent relations satisfy the predicate" do
      state =
        state_with(
          static: [fields: [%{name: :title, depends_on: nil, type: :text}]],
          field_values: %{}
        )

      load_fn = fn _, _, _ -> raise "shouldn't be called" end
      assert Helpers.load_dependent_relations(:socket, state, load_fn) == :socket
    end
  end
end

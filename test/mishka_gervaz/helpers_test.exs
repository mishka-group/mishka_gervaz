defmodule MishkaGervaz.HelpersTest do
  @moduledoc """
  Tests for the MishkaGervaz.Helpers module.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Helpers

  describe "humanize/1" do
    test "converts atom with underscores to title case" do
      assert Helpers.humanize(:first_name) == "First Name"
    end

    test "converts simple atom to capitalized string" do
      assert Helpers.humanize(:name) == "Name"
    end

    test "handles atom with multiple underscores" do
      assert Helpers.humanize(:user_profile_id) == "User Profile Id"
    end

    test "handles atom ending with _id" do
      assert Helpers.humanize(:user_id) == "User Id"
    end

    test "returns string as-is" do
      assert Helpers.humanize("already_formatted") == "already_formatted"
    end

    test "returns empty string for empty string" do
      assert Helpers.humanize("") == ""
    end

    test "handles single character atom" do
      assert Helpers.humanize(:a) == "A"
    end

    test "handles atom with numbers" do
      assert Helpers.humanize(:field_1) == "Field 1"
    end

    test "handles atom with consecutive underscores" do
      assert Helpers.humanize(:some__field) == "Some Field"
    end
  end

  describe "normalize_options/1" do
    test "returns empty list for nil" do
      assert Helpers.normalize_options(nil) == []
    end

    test "returns empty list for non-list input" do
      assert Helpers.normalize_options(:not_a_list) == []
      assert Helpers.normalize_options(%{}) == []
    end

    test "stringifies atom values from {label, atom} tuples" do
      assert Helpers.normalize_options([{"API Only", :api_only}]) == [{"API Only", "api_only"}]

      assert Helpers.normalize_options([{"API Only", :api_only}, {"Hybrid", :hybrid}]) ==
               [{"API Only", "api_only"}, {"Hybrid", "hybrid"}]
    end

    test "stringifies non-atom values from {label, value} tuples" do
      assert Helpers.normalize_options([{"One", 1}, {"Two", 2}]) ==
               [{"One", "1"}, {"Two", "2"}]

      assert Helpers.normalize_options([{"True", true}]) == [{"True", "true"}]
    end

    test "stringifies labels in {label, value} tuples" do
      assert Helpers.normalize_options([{:atom_label, "v"}]) == [{"atom_label", "v"}]
    end

    test "humanizes bare atom values into {Humanized, stringified} pairs" do
      assert Helpers.normalize_options([:active, :inactive]) ==
               [{"Active", "active"}, {"Inactive", "inactive"}]

      assert Helpers.normalize_options([:user_id, :created_at]) ==
               [{"User Id", "user_id"}, {"Created At", "created_at"}]
    end

    test "stringifies bare non-atom values into {value, value} pairs" do
      assert Helpers.normalize_options(["foo", "bar"]) ==
               [{"foo", "foo"}, {"bar", "bar"}]

      assert Helpers.normalize_options([1, 2, 3]) ==
               [{"1", "1"}, {"2", "2"}, {"3", "3"}]
    end

    test "handles mixed forms in a single list" do
      assert Helpers.normalize_options([{"A", :a}, :b, "c"]) ==
               [{"A", "a"}, {"B", "b"}, {"c", "c"}]
    end

    test "handles empty list" do
      assert Helpers.normalize_options([]) == []
    end
  end

  describe "format_filesize/1" do
    test "formats bytes" do
      assert Helpers.format_filesize(0) == "0 B"
      assert Helpers.format_filesize(1) == "1 B"
      assert Helpers.format_filesize(500) == "500 B"
      assert Helpers.format_filesize(1023) == "1023 B"
    end

    test "formats kilobytes at the boundary and above" do
      assert Helpers.format_filesize(1024) == "1.0 KB"
      assert Helpers.format_filesize(1536) == "1.5 KB"
      assert Helpers.format_filesize(1_048_575) == "1024.0 KB"
    end

    test "formats megabytes" do
      assert Helpers.format_filesize(1_048_576) == "1.0 MB"
      assert Helpers.format_filesize(5 * 1_048_576) == "5.0 MB"
    end

    test "formats gigabytes" do
      assert Helpers.format_filesize(1_073_741_824) == "1.0 GB"
      assert Helpers.format_filesize(2 * 1_073_741_824) == "2.0 GB"
    end

    test "returns dash for nil" do
      assert Helpers.format_filesize(nil) == "-"
    end

    test "returns dash for non-integer values" do
      assert Helpers.format_filesize("100") == "-"
      assert Helpers.format_filesize(:size) == "-"
      assert Helpers.format_filesize(1.5) == "-"
    end
  end

  describe "known_name?/2 (auto-detect by static map shape)" do
    test "returns true for a known field name (form state)" do
      state = %{static: %{fields: [%{name: :title}, %{name: :tags}]}}
      assert Helpers.known_name?("title", state) == true
      assert Helpers.known_name?("tags", state) == true
    end

    test "returns false for an unknown field name (form state)" do
      state = %{static: %{fields: [%{name: :title}]}}
      assert Helpers.known_name?("unknown", state) == false
    end

    test "returns true for a known column name (table state)" do
      state = %{static: %{columns: [%{name: :id}, %{name: :status}]}}
      assert Helpers.known_name?("id", state) == true
      assert Helpers.known_name?("status", state) == true
    end

    test "returns false for unknown column name" do
      state = %{static: %{columns: [%{name: :id}]}}
      assert Helpers.known_name?("ghost", state) == false
    end

    test "returns false for non-binary name" do
      state = %{static: %{fields: [%{name: :title}]}}
      assert Helpers.known_name?(:title, state) == false
      assert Helpers.known_name?(123, state) == false
    end

    test "returns false when static is missing or wrong shape" do
      assert Helpers.known_name?("x", %{}) == false
      assert Helpers.known_name?("x", %{static: %{}}) == false
      assert Helpers.known_name?("x", %{static: %{fields: nil}}) == false
    end

    test "returns false when fields list is empty" do
      state = %{static: %{fields: []}}
      assert Helpers.known_name?("anything", state) == false
    end
  end

  describe "known_name?/3 (explicit kind dispatch)" do
    test ":filters — returns true for known filter name" do
      state = %{static: %{filters: [%{name: :search}, %{name: :status}]}}
      assert Helpers.known_name?("search", state, :filters) == true
      assert Helpers.known_name?("status", state, :filters) == true
    end

    test ":filters — returns false for unknown filter" do
      state = %{static: %{filters: [%{name: :search}]}}
      assert Helpers.known_name?("ghost", state, :filters) == false
    end

    test ":steps — returns true for known step name" do
      state = %{static: %{steps: [%{name: :basics}, %{name: :review}]}}
      assert Helpers.known_name?("basics", state, :steps) == true
      assert Helpers.known_name?("review", state, :steps) == true
    end

    test ":steps — returns false for unknown step" do
      state = %{static: %{steps: [%{name: :basics}]}}
      assert Helpers.known_name?("ghost", state, :steps) == false
    end

    test ":uploads — returns true for known upload name" do
      state = %{static: %{uploads: [%{name: :avatar}, %{name: :document}]}}
      assert Helpers.known_name?("avatar", state, :uploads) == true
      assert Helpers.known_name?("document", state, :uploads) == true
    end

    test ":uploads — returns false for unknown upload" do
      state = %{static: %{uploads: [%{name: :avatar}]}}
      assert Helpers.known_name?("ghost", state, :uploads) == false
    end

    test "returns false for non-binary name regardless of kind" do
      state = %{static: %{filters: [%{name: :search}]}}
      assert Helpers.known_name?(:search, state, :filters) == false
    end

    test "returns false when static is missing the kind key" do
      assert Helpers.known_name?("x", %{static: %{}}, :filters) == false
      assert Helpers.known_name?("x", %{static: %{}}, :steps) == false
      assert Helpers.known_name?("x", %{static: %{}}, :uploads) == false
    end

    test "returns false when kind list is nil or wrong type" do
      assert Helpers.known_name?("x", %{static: %{filters: nil}}, :filters) == false
      assert Helpers.known_name?("x", %{static: %{filters: %{}}}, :filters) == false
    end

    test "returns false when state shape is invalid" do
      assert Helpers.known_name?("x", %{}, :filters) == false
      assert Helpers.known_name?("x", nil, :filters) == false
    end

    test "returns false when kind list is empty" do
      state = %{static: %{filters: []}}
      assert Helpers.known_name?("anything", state, :filters) == false
    end
  end

  describe "extract_singleton_entity/2" do
    defmodule SomeStruct do
      @moduledoc false
      defstruct [:value]
    end

    test "single-element list collapses to the head element" do
      ui = %SomeStruct{value: :ok}
      assert Helpers.extract_singleton_entity(%{ui: [ui]}, :ui) == %{ui: ui}
    end

    test "multi-element list still collapses to the head (first wins)" do
      first = %SomeStruct{value: :first}
      second = %SomeStruct{value: :second}

      assert Helpers.extract_singleton_entity(%{ui: [first, second]}, :ui) == %{ui: first}
    end

    test "empty list collapses to nil" do
      assert Helpers.extract_singleton_entity(%{ui: []}, :ui) == %{ui: nil}
    end

    test "already-extracted struct is left untouched (idempotent)" do
      ui = %SomeStruct{value: :existing}
      input = %{ui: ui}
      assert Helpers.extract_singleton_entity(input, :ui) == input
    end

    test "missing key is a no-op (no key inserted)" do
      assert Helpers.extract_singleton_entity(%{other: 1}, :ui) == %{other: 1}
    end

    test "non-list / non-struct value is left untouched" do
      assert Helpers.extract_singleton_entity(%{ui: :atom_value}, :ui) == %{ui: :atom_value}
      assert Helpers.extract_singleton_entity(%{ui: nil}, :ui) == %{ui: nil}
    end

    test "operates on the requested key only — other keys untouched" do
      ui = %SomeStruct{value: :u}
      preload = %SomeStruct{value: :p}

      assert Helpers.extract_singleton_entity(%{ui: [ui], preload: [preload]}, :ui) ==
               %{ui: ui, preload: [preload]}
    end

    test "chains cleanly via the pipe operator" do
      ui = %SomeStruct{value: :u}
      create = %SomeStruct{value: :c}

      result =
        %{ui: [ui], create: [create], update: [], cancel: nil}
        |> Helpers.extract_singleton_entity(:ui)
        |> Helpers.extract_singleton_entity(:create)
        |> Helpers.extract_singleton_entity(:update)
        |> Helpers.extract_singleton_entity(:cancel)

      assert result == %{ui: ui, create: create, update: nil, cancel: nil}
    end
  end

  describe "compact_to_nil/1" do
    test "drops nil values and returns the cleaned map" do
      assert Helpers.compact_to_nil(%{a: 1, b: nil, c: 2}) == %{a: 1, c: 2}
    end

    test "returns nil when the input map is empty" do
      assert Helpers.compact_to_nil(%{}) == nil
    end

    test "returns nil when every value is nil" do
      assert Helpers.compact_to_nil(%{a: nil, b: nil}) == nil
    end

    test "is idempotent on nil input" do
      assert Helpers.compact_to_nil(nil) == nil
    end

    test "preserves non-nil falsy values (false, 0, [], \"\")" do
      assert Helpers.compact_to_nil(%{a: false, b: 0, c: [], d: ""}) ==
               %{a: false, b: 0, c: [], d: ""}
    end

    test "leaves nested maps alone — only top-level nil values are pruned" do
      result = Helpers.compact_to_nil(%{a: %{b: nil}, c: nil})
      assert result == %{a: %{b: nil}}
    end
  end

  describe "normalize_id_type/1" do
    test "bare atoms" do
      assert Helpers.normalize_id_type(:uuid) == :uuid
      assert Helpers.normalize_id_type(:integer) == :integer
      assert Helpers.normalize_id_type(:string) == :string
    end

    test "Ash.Type.* modules" do
      assert Helpers.normalize_id_type(Ash.Type.UUID) == :uuid
      assert Helpers.normalize_id_type(Ash.Type.Integer) == :integer
      assert Helpers.normalize_id_type(Ash.Type.String) == :string
    end

    test "UUIDv7 module is detected as :uuid_v7" do
      uuid_v7_module = Module.concat([Ash, Type, UUIDv7])
      assert Helpers.normalize_id_type(uuid_v7_module) == :uuid_v7
    end

    test "vendor UUID variants fall back to :uuid" do
      assert Helpers.normalize_id_type(Module.concat([Ash, Type, UUIDFancy])) == :uuid
    end

    test "vendor Integer variants fall back to :integer" do
      assert Helpers.normalize_id_type(Module.concat([Ash, Type, IntegerFancy])) == :integer
    end

    test "unknown atoms default to :uuid" do
      assert Helpers.normalize_id_type(:something_weird) == :uuid
    end

    test "non-atom inputs default to :uuid" do
      assert Helpers.normalize_id_type(nil) == :uuid
      assert Helpers.normalize_id_type("uuid") == :uuid
      assert Helpers.normalize_id_type(42) == :uuid
    end
  end

  describe "primary_key_type/1" do
    test "returns :uuid for the standard test resource (uuid_primary_key :id)" do
      assert Helpers.primary_key_type(MishkaGervaz.Test.Resources.Post) == :uuid
    end

    test "returns :uuid for an unknown module (introspection rescues)" do
      assert Helpers.primary_key_type(NonExistentModule) == :uuid
    end
  end

  describe "relation_target_resource/2" do
    test "returns :resource directly when set on the entity" do
      entity = %{name: :user_id, source: nil, resource: MishkaGervaz.Test.Resources.User}

      assert Helpers.relation_target_resource(entity, nil) ==
               MishkaGervaz.Test.Resources.User
    end

    test "looks up via parent's Ash relationships when :resource is nil" do
      # FormPost has belongs_to :user, MishkaGervaz.Test.Resources.User
      entity = %{name: :user_id, source: nil, resource: nil}

      assert Helpers.relation_target_resource(entity, MishkaGervaz.Test.Resources.FormPost) ==
               MishkaGervaz.Test.Resources.User
    end

    test "honors `source` when it differs from `name`" do
      entity = %{name: :author, source: :user_id, resource: nil}

      assert Helpers.relation_target_resource(entity, MishkaGervaz.Test.Resources.FormPost) ==
               MishkaGervaz.Test.Resources.User
    end

    test "returns nil when no relationship matches the source/name" do
      entity = %{name: :nonexistent, source: nil, resource: nil}
      assert Helpers.relation_target_resource(entity, MishkaGervaz.Test.Resources.FormPost) == nil
    end

    test "returns nil when parent is nil and no :resource is set" do
      entity = %{name: :anything, source: nil, resource: nil}
      assert Helpers.relation_target_resource(entity, nil) == nil
    end

    test "returns nil for entities missing the expected keys" do
      assert Helpers.relation_target_resource(%{}, nil) == nil
      assert Helpers.relation_target_resource(:not_a_map, nil) == nil
    end
  end

  describe "relation_id_type/2" do
    test "returns the primary-key type of the related resource" do
      entity = %{type: :relation, name: :user_id, source: nil, resource: nil}

      assert Helpers.relation_id_type(entity, MishkaGervaz.Test.Resources.FormPost) == :uuid
    end

    test "falls back to :uuid when the relation cannot be resolved" do
      entity = %{type: :relation, name: :nonexistent, source: nil, resource: nil}
      assert Helpers.relation_id_type(entity, MishkaGervaz.Test.Resources.FormPost) == :uuid
    end

    test "returns nil for non-relation entities" do
      assert Helpers.relation_id_type(%{type: :text}, nil) == nil
      assert Helpers.relation_id_type(%{type: :select}, nil) == nil
    end
  end
end

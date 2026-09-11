defmodule MishkaGervaz.Form.Types.KeyMapTest do
  @moduledoc """
  A map whose keys are known, and the coercion that makes a nested sub-field's value the type it was
  declared as.

  `:json` stays the right field for a shape nobody can predict. This is for the many constrained-map
  columns whose keys are declared and few — and for the bug that came with them: a browser sends
  every input as a string, a top-level field is cast by Ash, and a nested field on a bare `:map`
  column is cast by nothing at all. A `:checkbox` sub-field stored `"true"`, and every reader that
  asked `== true` — as anything reading a boolean should — said no.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.KeyMap
  alias MishkaGervaz.Form.Types.Field.Nested

  defp declared do
    [
      [name: :required, type: :toggle, label: "Required"],
      [name: :default, type: :text],
      [name: :doc, type: :text]
    ]
  end

  describe "keys/1" do
    test "reads the declaration off options, where a select already keeps its list" do
      assert [%{name: :required, type: :toggle}, %{name: :default}, %{name: :doc}] =
               KeyMap.keys(%{options: declared()})
    end

    test "defaults a key with no type to text, and drops one with no name" do
      assert [%{name: :doc, type: :text}] = KeyMap.keys(%{options: [[name: :doc], [label: "x"]]})
    end

    test "and says nothing when nothing is declared" do
      assert KeyMap.keys(%{}) == []
      assert KeyMap.keys(nil) == []
    end
  end

  # EMPTY MEANS ABSENT. A constrained map is read by asking whether a key is there — Phoenix's own
  # `attr` treats `default: nil` and no default as different things — so writing every declared key
  # on every save would turn "not set" into "set to nothing" for every reader downstream.
  describe "parse_params/2" do
    test "keeps only the declared keys" do
      value = %{"required" => "true", "doc" => "hi", "smuggled" => "x"}

      assert KeyMap.parse_params(value, %{options: declared()}) == %{
               "required" => "true",
               "doc" => "hi"
             }
    end

    # Coerced first, pruned second, and that order is the point: a toggle left off arrives as the
    # string "false" from its hidden companion, and is only recognisable as "nothing to store" once
    # it is a boolean. `Nested.parse_params/2` runs the pair, which is what production does.
    test "drops a key left blank rather than writing an empty string" do
      value = %{"required" => false, "default" => "  ", "doc" => "hi"}

      assert KeyMap.parse_params(value, %{options: declared()}) == %{"doc" => "hi"}
    end

    test "and the pair together turn an untouched form row into nothing at all" do
      row = %{"opts" => %{"required" => "false", "default" => "", "doc" => ""}}
      subs = [%{name: :opts, type: :key_map, options: declared()}]

      assert [%{"opts" => %{}}] = Nested.parse_params([row], %{nested_fields: subs})
    end
  end

  # The other half: what the row is worth once it has been parsed.
  describe "a nested row's values are the types they were declared as" do
    defp rows(value), do: Nested.parse_params(value, %{nested_fields: subs()})

    defp subs do
      [
        %{name: :name, type: :text},
        %{name: :count, type: :number},
        %{name: :live, type: :checkbox},
        %{name: :opts, type: :key_map, options: declared()}
      ]
    end

    test "a checkbox becomes a boolean, not the string the browser sent" do
      assert [%{"live" => true}] = rows([%{"live" => "true"}])
      assert [%{"live" => false}] = rows([%{"live" => "false"}])
    end

    test "a number becomes a number" do
      assert [%{"count" => 3}] = rows([%{"count" => "3"}])
      assert [%{"count" => 1.5}] = rows([%{"count" => "1.5"}])
    end

    test "and a key map's own keys are coerced the same way" do
      assert [%{"opts" => %{"required" => true}}] = rows([%{"opts" => %{"required" => "true"}}])
    end

    test "text is left exactly as it came" do
      assert [%{"name" => " spaced "}] = rows([%{"name" => " spaced "}])
    end

    test "anything it cannot make sense of passes through untouched" do
      assert [%{"count" => "later"}] = rows([%{"count" => "later"}])
      assert [%{"live" => "maybe"}] = rows([%{"live" => "maybe"}])
    end

    test "a value already of the right type is not touched" do
      assert [%{"live" => true, "count" => 2}] = rows([%{"live" => true, "count" => 2}])
    end

    # A form posts its rows index-keyed rather than as a list.
    test "and the index-keyed shape a form posts is handled too" do
      assert %{"0" => %{"live" => true}} = rows(%{"0" => %{"live" => "true"}})
    end

    test "a field declaring no sub-fields is left alone entirely" do
      assert Nested.parse_params([%{"live" => "true"}], %{}) == [%{"live" => "true"}]
    end

    test "and a key the row does not carry is not invented" do
      assert [row] = rows([%{"name" => "x"}])
      refute Map.has_key?(row, "live")
    end
  end
end

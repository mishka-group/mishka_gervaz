defmodule MishkaGervaz.Form.Types.KeyListTest do
  @moduledoc """
  A list of maps whose keys are known — `:key_map` repeated, with rows to add and take away.

  The shape this was written for is a Phoenix slot's `attrs`: a list of `name` / `type` /
  `required` declarations, of which there may be none, one, or six. Given a JSON textarea for it, an
  author had to write `[{"name": "label", "type": "string"}]` by hand to declare one attribute.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.KeyList
  alias MishkaGervaz.Form.Types.Field.Nested

  defp declared do
    [
      [name: :name, type: :text],
      [name: :type, type: :select, options: ~w(string integer)],
      [name: :required, type: :toggle]
    ]
  end

  # A form posts `attrs[0][name]`, `attrs[1][name]`, which Phoenix hands back as an index-keyed map;
  # a map has no order, so the indices are the order. A value read back off the column is already a
  # list and is taken as it stands.
  describe "rows/1" do
    test "reads an index-keyed map in index order, not map order" do
      posted = %{"10" => %{"name" => "k"}, "2" => %{"name" => "b"}, "0" => %{"name" => "a"}}

      assert KeyList.rows(posted) == [%{"name" => "a"}, %{"name" => "b"}, %{"name" => "k"}]
    end

    test "takes a list as it stands" do
      assert KeyList.rows([%{"name" => "a"}, %{"name" => "b"}]) == [
               %{"name" => "a"},
               %{"name" => "b"}
             ]
    end

    # A form cannot post an empty list, so the template posts a sentinel to say the key is there and
    # holds nothing. It is not a row and must never be read as one.
    test "and drops anything that is not a row, the empty-list sentinel included" do
      assert KeyList.rows(%{"_empty" => "1"}) == []
      assert KeyList.rows(%{"_empty" => "1", "0" => %{"name" => "a"}}) == [%{"name" => "a"}]
      assert KeyList.rows(["nonsense", 3]) == []
      assert KeyList.rows(nil) == []
      assert KeyList.rows("[]") == []
    end
  end

  describe "parse_params/2" do
    test "keeps only the declared keys of each row" do
      value = %{"0" => %{"name" => "label", "smuggled" => "x"}}

      assert KeyList.parse_params(value, %{options: declared()}) == [%{"name" => "label"}]
    end

    # Pressing "add" and then thinking better of it should cost nothing, and neither should a row
    # left half-typed and abandoned — an empty row simply never reaches the column.
    test "drops a row with nothing left in it" do
      value = %{"0" => %{"name" => "label"}, "1" => %{"name" => "  ", "type" => ""}}

      assert KeyList.parse_params(value, %{options: declared()}) == [%{"name" => "label"}]
    end

    test "and a list with no rows at all is a list with no rows" do
      assert KeyList.parse_params(%{"_empty" => "1"}, %{options: declared()}) == []
    end
  end

  # The pair production actually runs. `Nested.parse_params/2` is what the form calls, and it casts
  # each row by its declared type before pruning it: a toggle left off arrives as the string "false"
  # from its hidden companion, and is only recognisable as nothing-to-store once it is a boolean.
  describe "through Nested.parse_params/2, the way the form calls it" do
    defp field do
      %{nested_fields: [%{name: :attrs, type: :key_list, options: declared()}]}
    end

    test "types each row's values and drops the blanks" do
      posted = %{
        "0" => %{
          "attrs" => %{
            "0" => %{"name" => "label", "type" => "string", "required" => "true"},
            "1" => %{"name" => "hint", "type" => "string", "required" => "false"}
          }
        }
      }

      assert %{"0" => %{"attrs" => rows}} = Nested.parse_params(posted, field())

      assert rows == [
               %{"name" => "label", "type" => "string", "required" => true},
               %{"name" => "hint", "type" => "string"}
             ]
    end

    test "and the sentinel alone empties the list rather than leaving it untouched" do
      posted = %{"0" => %{"attrs" => %{"_empty" => "1"}}}

      assert Nested.parse_params(posted, field()) == %{"0" => %{"attrs" => []}}
    end

    test "a row already stored as a list passes through unharmed" do
      posted = %{"0" => %{"attrs" => [%{"name" => "label", "required" => true}]}}

      assert Nested.parse_params(posted, field()) == %{
               "0" => %{"attrs" => [%{"name" => "label", "required" => true}]}
             }
    end
  end
end

defmodule MishkaGervaz.Form.Transformers.ConstrainedSubTypesTest do
  @moduledoc """
  The sub-fields inferred from a constrained map get the control their type asks for.

  Ash expands a shorthand before anyone else reads it — `type: :map` inside a `fields:` constraint
  is `Ash.Type.Map` by the time a transformer sees it — so matching the shorthands alone matched
  nothing and every sub-field of every constrained map fell through to a text box. A `:map` got a
  single-line input, a `:boolean` got one, an `:integer` got one.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ConstrainedMapForm

  defp sub_types(resource, field) do
    resource
    |> FormInfo.field(field)
    |> Map.get(:nested_fields)
    |> List.wrap()
    |> Map.new(&{&1.name, &1.type})
  end

  # `readings` declares no sub-fields at all, so every type below came from the constraint.
  test "each inferred sub-field gets the control its type asks for" do
    assert sub_types(ConstrainedMapForm, :readings) == %{
             label: :text,
             count: :number,
             ratio: :number,
             active: :checkbox,
             taken_on: :date,
             extra: :json
           }
  end

  # The bug in one line: the constraint is written `type: :map`, and by the time a transformer reads
  # it Ash has made it `Ash.Type.Map`. Clauses matching the shorthand matched nothing.
  test "because Ash rewrites the shorthand before the transformer sees it" do
    for shorthand <- [:string, :integer, :float, :decimal, :boolean, :date, :map] do
      assert Ash.Type.get_type(shorthand) != shorthand,
             "#{inspect(shorthand)} is expanded, which is why matching it alone never fired"
    end
  end
end

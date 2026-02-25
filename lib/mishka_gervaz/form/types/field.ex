defmodule MishkaGervaz.Form.Types.Field do
  @dialyzer :no_match

  @moduledoc """
  Built-in form field type registry.

  Provides lookup for built-in field types by atom name.
  Custom field types can be used directly by passing the module.
  """

  alias MishkaGervaz.Form.Types.Field

  use MishkaGervaz.Table.Behaviours.TypeRegistry,
    builtin: %{
      text: {Field.Text, [Ash.Type.String]},
      textarea: {Field.Textarea, []},
      number: {Field.Number, [Ash.Type.Integer, Ash.Type.Float, Ash.Type.Decimal]},
      checkbox: {Field.Checkbox, [Ash.Type.Boolean]},
      date: {Field.Date, [Ash.Type.Date]},
      datetime:
        {Field.DateTime, [Ash.Type.DateTime, Ash.Type.UtcDatetime, Ash.Type.UtcDatetimeUsec]},
      select: {Field.Select, []},
      multi_select: {Field.MultiSelect, []},
      relation: {Field.Relation, []},
      json: {Field.Json, [Ash.Type.Map]},
      nested: {Field.Nested, []},
      array_of_maps: {Field.ArrayOfMaps, []},
      string_list: {Field.StringList, []},
      file: {Field.File, []},
      hidden: {Field.Hidden, []},
      toggle: {Field.Toggle, []},
      range: {Field.Range, []},
      upload: {Field.Upload, []},
      combobox: {Field.Combobox, [Ash.Type.String]}
    },
    default: Field.Text
end

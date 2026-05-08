defmodule MishkaGervaz.Form.Types.Field do
  @dialyzer :no_match

  @moduledoc """
  Built-in form field type registry.

  Resolves field type atoms (`:text`, `:select`, `:relation`, …) to the
  implementation modules under `MishkaGervaz.Form.Types.Field.*`. Built on
  the shared `MishkaGervaz.Table.Behaviours.TypeRegistry` macro, which
  generates `get/1`, `builtin_types/0`, `builtin?/1`, `default/0`,
  `get_or_passthrough/1`, and `infer_from_ash_type/1`.

  ## Registration shape

  Each entry is `{Module, [AshTypes]}`. The Ash-type list seeds
  `infer_from_ash_type/1`, which is consulted by
  `MishkaGervaz.Form.Transformers.ResolveFields` whenever a field omits
  an explicit type — e.g. `field :title` on a `:string` attribute resolves
  to `Field.Text` because `Ash.Type.String` is mapped there. An empty list
  (`{Field.Hidden, []}`) means "this type is selectable by atom but never
  inferred from an Ash attribute".

  ## Custom field types

  Any module implementing `MishkaGervaz.Form.Behaviours.FieldType` can be
  referenced directly in the DSL — no registration needed:

      field :background_color, MyApp.FieldTypes.Color

  `get_or_passthrough/1` returns built-in modules by atom and any other
  atom value as-is, so custom modules pass straight through to the
  renderer.

  See `MishkaGervaz.Form.Behaviours.FieldType`,
  `MishkaGervaz.Table.Behaviours.TypeRegistry`, and
  `MishkaGervaz.Form.Transformers.ResolveFields`.
  """

  alias MishkaGervaz.Form.Types.Field

  use MishkaGervaz.Table.Behaviours.TypeRegistry,
    builtin: %{
      text: {Field.Text, [Ash.Type.String]},
      password: {Field.Password, []},
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

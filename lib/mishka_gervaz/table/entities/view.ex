defmodule MishkaGervaz.Table.Entities.View do
  @moduledoc """
  Entity struct for a named table view: another set of columns over the same resource, with a base
  filter of its own.

  A view keeps everything else of the resource's table (identity, source, filters, row and bulk
  actions, pagination, presentation). A mount picks it with the `view` assign of
  `MishkaGervaz.Table.Web.Live`; a mount that names no view draws the table itself.

  See `MishkaGervaz.Table.Dsl.Views`,
  `MishkaGervaz.Table.Transformers.ResolveColumns` (resolves its columns),
  `MishkaGervaz.Resource.Info.Table.view/2`, and
  `MishkaGervaz.Table.Web.State` (`apply_view/2`).
  """

  @type t :: %__MODULE__{
          name: atom(),
          filter: any(),
          column_set: __MODULE__.Columns.t() | [__MODULE__.Columns.t()] | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    :filter,
    column_set: [],
    __spark_metadata__: nil
  ]

  defmodule Columns do
    @moduledoc """
    The `columns` block of a view: its own columns, with the same options as the table's
    `columns` section. See `MishkaGervaz.Table.Entities.Column`.
    """

    @type t :: %__MODULE__{
            column_order: [atom()] | nil,
            default_sort: any(),
            columns: [MishkaGervaz.Table.Entities.Column.t()],
            __spark_metadata__: map() | nil
          }

    defstruct column_order: nil,
              default_sort: nil,
              columns: [],
              __spark_metadata__: nil
  end
end

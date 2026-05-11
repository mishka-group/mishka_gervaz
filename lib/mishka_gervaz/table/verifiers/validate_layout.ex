defmodule MishkaGervaz.Table.Verifiers.ValidateLayout do
  @moduledoc """
  Validates the chrome entities (header, footer, notice) declared inside
  the table layout section.

  Ensures that:
  - Notice names are unique
  - Notice positions are valid atoms or `{:before_column, name}` /
    `{:after_column, name}` tuples that reference an existing column

  See `MishkaGervaz.Table.Dsl.Layout`,
  `MishkaGervaz.Table.Entities.Notice`,
  `MishkaGervaz.Table.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.{Notice, Column}
  import MishkaGervaz.Table.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @layout_path [:mishka_gervaz, :table, :layout]
  @columns_path [:mishka_gervaz, :table, :columns]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    notices = entities_of(dsl_state, @layout_path, Notice)
    columns = entities_of(dsl_state, @columns_path, Column)

    with :ok <- validate_unique_notice_names(notices, module),
         :ok <- validate_notice_positions(notices, columns, module),
         do: :ok
  end

  defp validate_unique_notice_names(notices, module) do
    names = Enum.map(notices, & &1.name)

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      duplicates ->
        dsl_error(
          module,
          @layout_path ++ [:notice],
          "Duplicate notice names: #{inspect(Enum.uniq(duplicates))}"
        )
    end
  end

  defp validate_notice_positions(notices, columns, module) do
    column_names = MapSet.new(columns, & &1.name)
    Enum.find_value(notices, :ok, &check_notice_position(&1, column_names, module))
  end

  defp check_notice_position(notice, column_names, module) do
    case Notice.validate_position(notice.position) do
      :ok ->
        check_position_column(notice, column_names, module)

      {:error, reason} ->
        dsl_error(
          module,
          @layout_path ++ [:notice, notice.name],
          "Notice `#{notice.name}`: #{reason}"
        )
    end
  end

  defp check_position_column(%{position: {kind, col_name}} = notice, column_names, module)
       when kind in [:before_column, :after_column] do
    if MapSet.member?(column_names, col_name) do
      nil
    else
      dsl_error(
        module,
        @layout_path ++ [:notice, notice.name],
        "Notice `#{notice.name}` position #{inspect(notice.position)} references unknown column `#{col_name}`."
      )
    end
  end

  defp check_position_column(_notice, _column_names, _module), do: nil
end

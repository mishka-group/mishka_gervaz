defmodule MishkaGervaz.Table.Verifiers.ValidateLayout do
  @moduledoc """
  Validates the chrome entities (header, footer, notice) declared inside
  the table layout section.

  Ensures that:
  - Notice names are unique
  - Notice positions are valid atoms or `{:before_column, name}` /
    `{:after_column, name}` tuples that reference an existing column
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.{Notice, Column}

  @layout_path [:mishka_gervaz, :table, :layout]
  @columns_path [:mishka_gervaz, :table, :columns]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    notices =
      dsl_state
      |> Spark.Dsl.Transformer.get_entities(@layout_path)
      |> Enum.filter(&match?(%Notice{}, &1))

    columns =
      dsl_state
      |> Spark.Dsl.Transformer.get_entities(@columns_path)
      |> Enum.filter(&match?(%Column{}, &1))

    with :ok <- validate_unique_notice_names(notices, module),
         :ok <- validate_notice_positions(notices, columns, module) do
      :ok
    end
  end

  defp validate_unique_notice_names(notices, module) do
    names = Enum.map(notices, & &1.name)
    duplicates = names -- Enum.uniq(names)

    if duplicates == [] do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: @layout_path ++ [:notice],
         message: "Duplicate notice names: #{inspect(Enum.uniq(duplicates))}"
       )}
    end
  end

  defp validate_notice_positions(notices, columns, module) do
    column_names = MapSet.new(columns, & &1.name)

    Enum.reduce_while(notices, :ok, fn notice, :ok ->
      case Notice.validate_position(notice.position) do
        :ok ->
          case notice.position do
            {kind, col_name} when kind in [:before_column, :after_column] ->
              if MapSet.member?(column_names, col_name) do
                {:cont, :ok}
              else
                {:halt,
                 {:error,
                  Spark.Error.DslError.exception(
                    module: module,
                    path: @layout_path ++ [:notice, notice.name],
                    message:
                      "Notice `#{notice.name}` position #{inspect(notice.position)} references unknown column `#{col_name}`."
                  )}}
              end

            _ ->
              {:cont, :ok}
          end

        {:error, reason} ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              module: module,
              path: @layout_path ++ [:notice, notice.name],
              message: "Notice `#{notice.name}`: #{reason}"
            )}}
      end
    end)
  end
end

defmodule MishkaGervaz.Form.Verifiers.ValidateChrome do
  @moduledoc """
  Validates the chrome entities (header, footer, notice) declared inside
  the layout section of MishkaGervaz form DSL.

  Ensures that:
  - Notice names are unique
  - Notice positions are valid atoms or `{:before_group, name}` /
    `{:after_group, name}` tuples that reference an existing group
  - Notice `only_steps` references existing steps
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Notice, Group, Step}

  @layout_path [:mishka_gervaz, :form, :layout]
  @groups_path [:mishka_gervaz, :form, :groups]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    layout_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @layout_path)
    notices = Enum.filter(layout_entities, &match?(%Notice{}, &1))
    steps = Enum.filter(layout_entities, &match?(%Step{}, &1))

    group_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @groups_path)
    groups = Enum.filter(group_entities, &match?(%Group{}, &1))

    with :ok <- validate_unique_notice_names(notices, module),
         :ok <- validate_notice_positions(notices, groups, module),
         :ok <- validate_notice_only_steps(notices, steps, module) do
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

  defp validate_notice_positions(notices, groups, module) do
    group_names = MapSet.new(groups, & &1.name)

    Enum.reduce_while(notices, :ok, fn notice, :ok ->
      case Notice.validate_position(notice.position) do
        :ok ->
          case notice.position do
            {kind, group_name} when kind in [:before_group, :after_group] ->
              if MapSet.member?(group_names, group_name) do
                {:cont, :ok}
              else
                {:halt,
                 {:error,
                  Spark.Error.DslError.exception(
                    module: module,
                    path: @layout_path ++ [:notice, notice.name],
                    message:
                      "Notice `#{notice.name}` position #{inspect(notice.position)} references unknown group `#{group_name}`."
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

  defp validate_notice_only_steps(notices, steps, module) do
    step_names = MapSet.new(steps, & &1.name)

    Enum.reduce_while(notices, :ok, fn notice, :ok ->
      case notice.only_steps do
        nil ->
          {:cont, :ok}

        steps_list when is_list(steps_list) ->
          missing = Enum.reject(steps_list, &MapSet.member?(step_names, &1))

          if missing == [] do
            {:cont, :ok}
          else
            {:halt,
             {:error,
              Spark.Error.DslError.exception(
                module: module,
                path: @layout_path ++ [:notice, notice.name],
                message:
                  "Notice `#{notice.name}` only_steps references unknown steps: #{inspect(missing)}"
              )}}
          end
      end
    end)
  end
end

defmodule MishkaGervaz.Form.Verifiers.ValidateSteps do
  @moduledoc """
  Validates the step configuration within the layout section of MishkaGervaz form DSL.

  Ensures that:
  - Steps are present when mode is `:wizard` or `:tabs`, forbidden for `:standard`
  - All step group references exist in defined groups
  - No group appears in multiple steps
  - At most one `summary: true` step
  - `navigation: :free` is not valid with `:wizard` mode
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Group, Step}

  @layout_path [:mishka_gervaz, :form, :layout]
  @groups_path [:mishka_gervaz, :form, :groups]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    mode = Spark.Dsl.Transformer.get_option(dsl_state, @layout_path, :mode, :standard)

    navigation =
      Spark.Dsl.Transformer.get_option(dsl_state, @layout_path, :navigation, :sequential)

    step_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @layout_path) |> List.wrap()
    steps = Enum.filter(step_entities, &match?(%Step{}, &1))

    group_entities = Spark.Dsl.Transformer.get_entities(dsl_state, @groups_path) |> List.wrap()
    groups = Enum.filter(group_entities, &match?(%Group{}, &1))
    group_names = Enum.map(groups, & &1.name)

    with :ok <- validate_steps_presence(steps, mode, module),
         :ok <- validate_navigation_mode(navigation, mode, module),
         :ok <- validate_group_references(steps, group_names, module),
         :ok <- validate_no_duplicate_groups(steps, module),
         :ok <- validate_single_summary(steps, module) do
      :ok
    end
  end

  defp validate_steps_presence(steps, mode, module) do
    cond do
      mode in [:wizard, :tabs] and steps == [] ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: @layout_path,
           message: "Layout mode `#{mode}` requires at least one step to be defined."
         )}

      mode == :standard and steps != [] ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: @layout_path,
           message: "Steps cannot be defined when layout mode is `:standard`."
         )}

      true ->
        :ok
    end
  end

  defp validate_navigation_mode(navigation, mode, module) do
    if navigation == :free and mode == :wizard do
      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: @layout_path,
         message:
           "Navigation `:free` is not valid with `:wizard` mode. " <>
             "Wizard mode requires `:sequential` navigation. Use `:tabs` mode for free navigation."
       )}
    else
      :ok
    end
  end

  defp validate_group_references(steps, group_names, module) do
    Enum.reduce_while(steps, :ok, fn step, :ok ->
      missing = Enum.reject(step.groups, &(&1 in group_names))

      if missing == [] do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            module: module,
            path: @layout_path ++ [step.name],
            message: "Step `#{step.name}` references groups that don't exist: #{inspect(missing)}"
          )}}
      end
    end)
  end

  defp validate_no_duplicate_groups(steps, module) do
    {_, result} =
      Enum.reduce_while(steps, {MapSet.new(), :ok}, fn step, {seen, :ok} ->
        duplicates = Enum.filter(step.groups, &MapSet.member?(seen, &1))

        if duplicates == [] do
          new_seen = Enum.reduce(step.groups, seen, &MapSet.put(&2, &1))
          {:cont, {new_seen, :ok}}
        else
          {:halt,
           {seen,
            {:error,
             Spark.Error.DslError.exception(
               module: module,
               path: @layout_path ++ [step.name],
               message:
                 "Step `#{step.name}` contains groups already in another step: #{inspect(duplicates)}"
             )}}}
        end
      end)

    result
  end

  defp validate_single_summary(steps, module) do
    summary_steps = Enum.filter(steps, & &1.summary)

    if length(summary_steps) > 1 do
      names = Enum.map(summary_steps, & &1.name)

      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: @layout_path,
         message:
           "At most one step can have `summary: true`, but found #{length(summary_steps)}: #{inspect(names)}"
       )}
    else
      :ok
    end
  end
end

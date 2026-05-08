defmodule MishkaGervaz.Form.Verifiers.ValidateSteps do
  @moduledoc """
  Validates the step configuration within the `layout` section of
  MishkaGervaz form DSL.

  Five checks, in order:

    1. Steps must be present when mode is `:wizard` or `:tabs`, and absent
       when mode is `:standard`.
    2. `navigation: :free` is incompatible with `:wizard` mode (wizards are
       sequential by design; use `:tabs` for free navigation).
    3. Each step's `groups` reference an existing group.
    4. No group appears in more than one step.
    5. At most one step is marked as `summary: true`.

  See `MishkaGervaz.Form.Dsl.Layout`,
  `MishkaGervaz.Form.Entities.Step`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Group, Step}

  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @layout_path [:mishka_gervaz, :form, :layout]
  @groups_path [:mishka_gervaz, :form, :groups]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    mode = Spark.Dsl.Transformer.get_option(dsl_state, @layout_path, :mode, :standard)

    navigation =
      Spark.Dsl.Transformer.get_option(dsl_state, @layout_path, :navigation, :sequential)

    steps = entities_of(dsl_state, @layout_path, Step)
    group_names = dsl_state |> entities_of(@groups_path, Group) |> Enum.map(& &1.name)

    with :ok <- validate_steps_presence(steps, mode, module),
         :ok <- validate_navigation_mode(navigation, mode, module),
         :ok <- validate_group_references(steps, group_names, module),
         :ok <- validate_no_duplicate_groups(steps, module),
         :ok <- validate_single_summary(steps, module),
         do: :ok
  end

  defp validate_steps_presence([], mode, module) when mode in [:wizard, :tabs] do
    dsl_error(
      module,
      @layout_path,
      "Layout mode `#{mode}` requires at least one step to be defined."
    )
  end

  defp validate_steps_presence([_ | _], :standard, module) do
    dsl_error(module, @layout_path, "Steps cannot be defined when layout mode is `:standard`.")
  end

  defp validate_steps_presence(_steps, _mode, _module), do: :ok

  defp validate_navigation_mode(:free, :wizard, module) do
    dsl_error(
      module,
      @layout_path,
      "Navigation `:free` is not valid with `:wizard` mode. " <>
        "Wizard mode requires `:sequential` navigation. Use `:tabs` mode for free navigation."
    )
  end

  defp validate_navigation_mode(_navigation, _mode, _module), do: :ok

  defp validate_group_references(steps, group_names, module) do
    Enum.find_value(steps, :ok, &check_group_references(&1, group_names, module))
  end

  defp check_group_references(step, group_names, module) do
    case Enum.reject(step.groups, &(&1 in group_names)) do
      [] ->
        nil

      missing ->
        dsl_error(
          module,
          @layout_path ++ [step.name],
          "Step `#{step.name}` references groups that don't exist: #{inspect(missing)}"
        )
    end
  end

  defp validate_no_duplicate_groups(steps, module) do
    steps
    |> Enum.reduce_while({MapSet.new(), :ok}, &check_for_duplicates(&1, &2, module))
    |> elem(1)
  end

  defp check_for_duplicates(step, {seen, _}, module) do
    case Enum.filter(step.groups, &MapSet.member?(seen, &1)) do
      [] ->
        {:cont, {Enum.into(step.groups, seen), :ok}}

      dups ->
        {:halt,
         {seen,
          dsl_error(
            module,
            @layout_path ++ [step.name],
            "Step `#{step.name}` contains groups already in another step: #{inspect(dups)}"
          )}}
    end
  end

  defp validate_single_summary(steps, module) do
    case Enum.filter(steps, & &1.summary) do
      list when length(list) <= 1 ->
        :ok

      summaries ->
        names = Enum.map(summaries, & &1.name)

        dsl_error(
          module,
          @layout_path,
          "At most one step can have `summary: true`, but found #{length(summaries)}: #{inspect(names)}"
        )
    end
  end
end

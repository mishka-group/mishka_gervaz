defmodule MishkaGervaz.Form.Verifiers.ValidateChrome do
  @moduledoc """
  Validates the chrome entities (header, footer, notice) declared inside
  the `layout` section of MishkaGervaz form DSL.

  Three checks, in order:

    1. Notice names are unique within a form.
    2. Notice positions are valid atoms or `{:before_group, name}` /
       `{:after_group, name}` tuples that reference an existing group.
    3. Notice `only_steps` references existing step names.

  Position-shape validation is delegated to
  `MishkaGervaz.Form.Entities.Notice.validate_position/1`.

  See `MishkaGervaz.Form.Dsl.Layout`,
  `MishkaGervaz.Form.Entities.Notice`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Group, Notice, Step}

  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @layout_path [:mishka_gervaz, :form, :layout]
  @groups_path [:mishka_gervaz, :form, :groups]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    notices = entities_of(dsl_state, @layout_path, Notice)
    steps = entities_of(dsl_state, @layout_path, Step)
    groups = entities_of(dsl_state, @groups_path, Group)

    with :ok <- validate_unique_notice_names(notices, module),
         :ok <- validate_notice_positions(notices, groups, module),
         :ok <- validate_notice_only_steps(notices, steps, module),
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

  defp validate_notice_positions(notices, groups, module) do
    group_names = MapSet.new(groups, & &1.name)
    Enum.find_value(notices, :ok, &check_notice_position(&1, group_names, module))
  end

  defp check_notice_position(notice, group_names, module) do
    case Notice.validate_position(notice.position) do
      :ok ->
        check_position_group(notice, group_names, module)

      {:error, reason} ->
        dsl_error(
          module,
          @layout_path ++ [:notice, notice.name],
          "Notice `#{notice.name}`: #{reason}"
        )
    end
  end

  defp check_position_group(%{position: {kind, group_name}} = notice, group_names, module)
       when kind in [:before_group, :after_group] do
    if MapSet.member?(group_names, group_name) do
      nil
    else
      dsl_error(
        module,
        @layout_path ++ [:notice, notice.name],
        "Notice `#{notice.name}` position #{inspect(notice.position)} references unknown group `#{group_name}`."
      )
    end
  end

  defp check_position_group(_notice, _group_names, _module), do: nil

  defp validate_notice_only_steps(notices, steps, module) do
    step_names = MapSet.new(steps, & &1.name)
    Enum.find_value(notices, :ok, &check_only_steps(&1, step_names, module))
  end

  defp check_only_steps(%{only_steps: nil}, _step_names, _module), do: nil

  defp check_only_steps(%{only_steps: only} = notice, step_names, module) when is_list(only) do
    case Enum.reject(only, &MapSet.member?(step_names, &1)) do
      [] ->
        nil

      missing ->
        dsl_error(
          module,
          @layout_path ++ [:notice, notice.name],
          "Notice `#{notice.name}` only_steps references unknown steps: #{inspect(missing)}"
        )
    end
  end
end

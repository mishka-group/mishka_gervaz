defmodule MishkaGervaz.Form.Verifiers.ValidatePreloads do
  @moduledoc """
  Validates the `source.preload` configuration of MishkaGervaz form DSL.

  Catches a runtime footgun at compile time: preloading a relationship
  whose read action requires pagination raises
  `Ash.Error.Invalid.LimitRequired` because preloads do not pass a `limit`.

  Triggers when, for any preload entry, the destination resource's read
  action has `pagination required?: true` (the default when `required?` is
  not set on the action's pagination block).

  See `MishkaGervaz.Form.Dsl.Source.Preload`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3]

  @preload_path [:mishka_gervaz, :form, :source, :preload]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    case all_preloads(dsl_state) do
      [] -> :ok
      preloads -> check_preloads(module, preloads)
    end
  end

  defp all_preloads(dsl_state) do
    [:always, :master, :tenant]
    |> Enum.flat_map(&(Verifier.get_option(dsl_state, @preload_path, &1) || []))
  end

  defp check_preloads(module, preloads) do
    relationships = Ash.Resource.Info.relationships(module)
    Enum.find_value(preloads, :ok, &check_preload(&1, relationships, module))
  end

  defp check_preload(preload, relationships, module) do
    name = preload_name(preload)

    case Enum.find(relationships, &(&1.name == name)) do
      nil -> nil
      rel -> check_relationship_pagination(rel, module)
    end
  end

  defp preload_name({name, _alias}) when is_atom(name), do: name
  defp preload_name(name) when is_atom(name), do: name

  defp check_relationship_pagination(rel, module) do
    read_action = rel.read_action || :read

    case Ash.Resource.Info.action(rel.destination, read_action) do
      %{pagination: %{required?: false}} ->
        nil

      %{pagination: %{} = _pagination} ->
        dsl_error(module, @preload_path, pagination_message(rel, read_action))

      _ ->
        nil
    end
  end

  defp pagination_message(rel, read_action) do
    """
    Preload :#{rel.name} uses action :#{read_action} on #{inspect(rel.destination)} \
    which has `pagination required?: true`.

    Preloads do not pass pagination parameters, so this will fail at runtime \
    with `Ash.Error.Invalid.LimitRequired`.

    Fix: add `required?: false` to the pagination options of the :#{read_action} action:

        read :#{read_action} do
          pagination offset?: true, required?: false, ...
        end
    """
  end
end

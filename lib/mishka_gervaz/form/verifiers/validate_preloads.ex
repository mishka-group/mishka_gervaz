defmodule MishkaGervaz.Form.Verifiers.ValidatePreloads do
  @moduledoc """
  Validates preload configuration for MishkaGervaz form DSL.

  Checks that preloaded relationships do not use read actions with
  `pagination required?: true` (the default when `required?` is not set).
  Such actions require a `limit` parameter, which preloads do not pass,
  causing `Ash.Error.Invalid.LimitRequired` at runtime.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  @preload_path [:mishka_gervaz, :form, :source, :preload]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    resource = module

    always = Verifier.get_option(dsl_state, @preload_path, :always) || []
    master = Verifier.get_option(dsl_state, @preload_path, :master) || []
    tenant = Verifier.get_option(dsl_state, @preload_path, :tenant) || []

    all_preloads = always ++ master ++ tenant

    if all_preloads == [] do
      :ok
    else
      check_preloads(resource, all_preloads, module)
    end
  end

  defp check_preloads(resource, preloads, module) do
    relationships = Ash.Resource.Info.relationships(resource)

    Enum.reduce_while(preloads, :ok, fn preload, _acc ->
      rel_name = extract_preload_name(preload)

      case Enum.find(relationships, &(&1.name == rel_name)) do
        nil ->
          {:cont, :ok}

        rel ->
          case check_relationship_pagination(rel) do
            :ok ->
              {:cont, :ok}

            {:error, message} ->
              {:halt,
               {:error,
                Spark.Error.DslError.exception(
                  module: module,
                  path: @preload_path,
                  message: message
                )}}
          end
      end
    end)
  end

  defp extract_preload_name({name, _alias}) when is_atom(name), do: name
  defp extract_preload_name(name) when is_atom(name), do: name

  defp check_relationship_pagination(rel) do
    dest_resource = rel.destination
    read_action_name = rel.read_action || :read

    case Ash.Resource.Info.action(dest_resource, read_action_name) do
      nil ->
        :ok

      action ->
        pagination = action.pagination

        if pagination && pagination_required?(pagination) do
          {:error,
           """
           Preload :#{rel.name} uses action :#{read_action_name} on #{inspect(dest_resource)} \
           which has `pagination required?: true`.

           Preloads do not pass pagination parameters, so this will fail at runtime \
           with `Ash.Error.Invalid.LimitRequired`.

           Fix: add `required?: false` to the pagination options of the :#{read_action_name} action:

               read :#{read_action_name} do
                 pagination offset?: true, required?: false, ...
               end
           """}
        else
          :ok
        end
    end
  end

  defp pagination_required?(%{required?: required?}), do: required? != false
  defp pagination_required?(_), do: false
end

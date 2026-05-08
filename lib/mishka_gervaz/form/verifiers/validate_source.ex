defmodule MishkaGervaz.Form.Verifiers.ValidateSource do
  @moduledoc """
  Validates the `source` section of MishkaGervaz form DSL.

  Ensures every required action (`create`, `update`, `read`) is defined
  either on the resource or inherited from the domain — compilation fails
  when both are nil. Resource overrides win when both are set.

  The verifier short-circuits when no fields are declared (a form without
  fields has no source to consume).

  The `master_check` requirement is enforced upstream by
  `MishkaGervaz.Form.Transformers.MergeDefaults.merge_master_check_default/1`,
  which always persists a fallback MFA when neither resource nor domain
  defines one — the verifier no longer guards that path.

  See `MishkaGervaz.Form.Dsl.Source`,
  `MishkaGervaz.Form.Transformers.MergeDefaults`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3]

  @actions_path [:mishka_gervaz, :form, :source, :actions]
  @fields_path [:mishka_gervaz, :form, :fields]

  @required_actions [:create, :update, :read]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    if form_used?(dsl_state),
      do: validate_required_actions(dsl_state),
      else: :ok
  end

  defp form_used?(dsl_state) do
    case Spark.Dsl.Transformer.get_entities(dsl_state, @fields_path) do
      [_ | _] -> true
      _ -> false
    end
  end

  defp validate_required_actions(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    domain_actions = domain_actions(module)

    @required_actions
    |> Enum.filter(fn key ->
      is_nil(Verifier.get_option(dsl_state, @actions_path, key)) and
        is_nil(Map.get(domain_actions, key))
    end)
    |> case do
      [] -> :ok
      missing -> dsl_error(module, @actions_path, missing_actions_message(missing))
    end
  end

  defp domain_actions(module) do
    with {:ok, domain} <- safe_domain(module),
         %{form: %{actions: actions}} when is_map(actions) <-
           Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      actions
    else
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp safe_domain(module) do
    case Ash.Resource.Info.domain(module) do
      nil -> :error
      domain -> {:ok, domain}
    end
  rescue
    _ -> :error
  end

  defp missing_actions_message(missing) do
    """
    Missing required form source action(s): #{Enum.map_join(missing, ", ", &inspect/1)}

    Each of #{Enum.map_join(@required_actions, ", ", &inspect/1)} must be defined
    either on the resource or on the domain. Resource values win when both are set.

    Provide them on the resource:

        mishka_gervaz do
          form do
            source do
              actions do
                create {:master_create, :create}
                update {:master_update, :update}
                read {:master_get, :read}
              end
            end
          end
        end

    Or on the domain (inherited by every form resource in the domain):

        mishka_gervaz do
          form do
            actions do
              create {:master_create, :create}
              update {:master_update, :update}
              read {:master_get, :read}
            end
          end
        end

    Each value can be a single atom (used for both master and tenant
    requests) or a tuple `{master_action, tenant_action}`.
    """
  end
end

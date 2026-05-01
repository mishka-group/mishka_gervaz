defmodule MishkaGervaz.Form.Verifiers.ValidateSource do
  @moduledoc """
  Validates the source section of MishkaGervaz form DSL.

  Ensures:
  - All three required actions (create, update, read) are defined either on
    the resource or inherited from the domain. Compile fails otherwise.
  - master_check is set when actions use master/tenant tuples.
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  @source_path [:mishka_gervaz, :form, :source]
  @actions_path [:mishka_gervaz, :form, :source, :actions]
  @fields_path [:mishka_gervaz, :form, :fields]

  @required_actions [:create, :update, :read]

  @impl true
  def verify(dsl_state) do
    if form_used?(dsl_state) do
      do_verify(dsl_state)
    else
      :ok
    end
  end

  defp form_used?(dsl_state) do
    case Verifier.get_entities(dsl_state, @fields_path) do
      [] -> false
      nil -> false
      list when is_list(list) -> true
    end
  end

  defp do_verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    with :ok <- validate_required_actions(dsl_state, module),
         :ok <- validate_master_check(dsl_state, module),
         do: :ok
  end

  defp validate_required_actions(dsl_state, module) do
    domain_actions = domain_actions(module)

    missing =
      Enum.filter(@required_actions, fn key ->
        is_nil(Verifier.get_option(dsl_state, @actions_path, key)) and
          is_nil(Map.get(domain_actions, key))
      end)

    case missing do
      [] -> :ok
      _ -> dsl_error(module, @actions_path, missing_actions_message(missing))
    end
  end

  defp validate_master_check(dsl_state, module) do
    create = action_value(dsl_state, module, :create)
    update = action_value(dsl_state, module, :update)
    read = action_value(dsl_state, module, :read)

    master_check = Verifier.get_option(dsl_state, @source_path, :master_check)

    default_master_check =
      Verifier.get_persisted(dsl_state, :mishka_gervaz_form_default_master_check)

    has_tuples = is_tuple(create) or is_tuple(update) or is_tuple(read)

    if has_tuples and is_nil(master_check) and is_nil(default_master_check) and
         not has_domain_master_check?(module) do
      dsl_error(module, @source_path, """
      master_check is required when actions use master/tenant tuples.

      Add a master_check function to the source section:

          source do
            master_check fn user -> user.role == :admin end
          end
      """)
    else
      :ok
    end
  end

  defp action_value(dsl_state, module, key) do
    Verifier.get_option(dsl_state, @actions_path, key) ||
      Map.get(domain_actions(module), key)
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

  defp has_domain_master_check?(module) do
    with {:ok, domain} <- safe_domain(module),
         %{form: %{master_check: mc}} when not is_nil(mc) <-
           Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      true
    else
      _ -> false
    end
  rescue
    _ -> false
  end

  defp safe_domain(module) do
    case Ash.Resource.Info.domain(module) do
      nil -> :error
      domain -> {:ok, domain}
    end
  rescue
    _ -> :error
  end

  defp dsl_error(module, path, message) do
    {:error, Spark.Error.DslError.exception(module: module, path: path, message: message)}
  end

  defp missing_actions_message(missing) do
    keys = Enum.map_join(missing, ", ", &inspect/1)

    """
    Missing required form source action(s): #{keys}

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

    Each value can be a single atom (used for both master and tenant requests)
    or a tuple `{master_action, tenant_action}`.
    """
  end
end

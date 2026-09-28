defmodule MishkaGervaz.Form.Verifiers.ValidateSource do
  @moduledoc """
  Validates the `source` section of MishkaGervaz form DSL.

  Ensures every required action (`create`, `update`, `read`) is defined
  either on the resource or inherited from the domain. Resource overrides win when both are set.

  Every action named that way — master and tenant alike — must be an action of the resource, of
  the matching kind: `create` a create action, `update` an update action, `read` a read action.
  A mode closed with `access :create, false` or `access :update, false` is not checked: `create`
  belongs to `:create`, `update` and `read` to `:update`.

  The verifier short-circuits when no fields are declared (a form without
  fields has no source to consume).

  Each failure is a `Spark.Error.DslError`, which Spark prints as a compile warning. Compile with
  `--warnings-as-errors` to fail the build on it.

  `master_check` is not checked here:
  `MishkaGervaz.Form.Transformers.MergeDefaults.merge_master_check_default/1` persists a fallback
  MFA when neither resource nor domain defines one.

  See `MishkaGervaz.Form.Dsl.Source`,
  `MishkaGervaz.Form.Transformers.MergeDefaults`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias MishkaGervaz.Form.Entities.Access
  alias Spark.Dsl.Verifier

  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]
  import MishkaGervaz.Helpers, only: [missing_actions: 4, missing_actions_message: 4]

  @source_path [:mishka_gervaz, :form, :source]
  @actions_path [:mishka_gervaz, :form, :source, :actions]
  @fields_path [:mishka_gervaz, :form, :fields]

  @required_actions [:create, :update, :read]

  @action_modes [create: :create, update: :update, read: :update]

  @fix """
  Add each action to the resource, or name one it has under
  `mishka_gervaz > form > source > actions`. A mode no screen opens can be closed instead, with
  `access :update, false` (or `access :create, false`) under `mishka_gervaz > form > source`.
  """

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    if form_used?(dsl_state) do
      with :ok <- validate_required_actions(dsl_state),
           do: validate_actions_exist(dsl_state)
    else
      :ok
    end
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
      missing -> dsl_error(module, @actions_path, required_actions_message(missing))
    end
  end

  defp validate_actions_exist(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    domain_actions = domain_actions(module)
    closed = closed_modes(dsl_state)

    @action_modes
    |> Enum.reject(fn {_key, mode} -> mode in closed end)
    |> Enum.flat_map(fn {key, _mode} ->
      set_here = Verifier.get_option(dsl_state, @actions_path, key)
      value = set_here || Map.get(domain_actions, key)
      origin = origin(set_here, module)

      dsl_state
      |> missing_actions(key, value, key)
      |> Enum.map(&Map.put(&1, :origin, origin))
    end)
    |> case do
      [] ->
        :ok

      missing ->
        dsl_error(module, @actions_path, missing_actions_message(module, "form", missing, @fix))
    end
  end

  defp closed_modes(dsl_state) do
    dsl_state
    |> entities_of(@source_path, Access)
    |> Enum.filter(&(&1.mode in [:create, :update] and &1.condition == false))
    |> Enum.map(& &1.mode)
  end

  defp origin(nil, module) do
    case safe_domain(module) do
      {:ok, domain} -> {:domain, domain}
      :error -> :resource
    end
  end

  defp origin(_set_here, _module), do: :resource

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

  defp required_actions_message(missing) do
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

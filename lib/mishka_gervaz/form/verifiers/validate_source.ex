defmodule MishkaGervaz.Form.Verifiers.ValidateSource do
  @moduledoc """
  Validates the source section of MishkaGervaz form DSL.

  Ensures:
  - Action tuples are valid
  - master_check is set when actions use master/tenant tuples
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  @source_path [:mishka_gervaz, :form, :source]
  @actions_path [:mishka_gervaz, :form, :source, :actions]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    create = Verifier.get_option(dsl_state, @actions_path, :create)
    update = Verifier.get_option(dsl_state, @actions_path, :update)
    read = Verifier.get_option(dsl_state, @actions_path, :read)
    master_check = Verifier.get_option(dsl_state, @source_path, :master_check)

    default_master_check =
      Verifier.get_persisted(dsl_state, :mishka_gervaz_form_default_master_check)

    has_tuples = is_tuple(create) or is_tuple(update) or is_tuple(read)

    if has_tuples and is_nil(master_check) and is_nil(default_master_check) do
      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: @source_path,
         message: """
         master_check is required when actions use master/tenant tuples.

         Add a master_check function to the source section:

             source do
               master_check fn user -> user.role == :admin end
             end
         """
       )}
    else
      :ok
    end
  end
end

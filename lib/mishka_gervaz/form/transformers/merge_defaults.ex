defmodule MishkaGervaz.Form.Transformers.MergeDefaults do
  @moduledoc """
  Merges default values into the form DSL configuration.

  This transformer fills in sensible defaults for unspecified options,
  including:

  - Inheriting defaults from the domain (if using `MishkaGervaz.Domain`)
  - Deriving `identity.name` from the resource module name
  - Generating `identity.stream_name` if not specified
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  import MishkaGervaz.Table.Transformers.Helpers
  import MishkaGervaz.Helpers, only: [module_to_snake: 2]

  @form_path [:mishka_gervaz, :form]

  @domain_mappings [
    {[:presentation], :ui_adapter},
    {[:presentation], :ui_adapter_opts},
    {[:source], :actor_key},
    {[:source], :master_check},
    {[:source, :actions], :create},
    {[:source, :actions], :update},
    {[:source, :actions], :read},
    {[:layout], :navigation},
    {[:layout], :persistence}
  ]

  @impl true
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)
    domain_defaults = get_domain_defaults(module)

    dsl_state =
      dsl_state
      |> merge_domain_defaults(domain_defaults)
      |> merge_identity_defaults(module)
      |> merge_master_check_default()

    {:ok, dsl_state}
  end

  @spec get_domain_defaults(module()) :: map() | nil
  defp get_domain_defaults(module) do
    case get_domain_config(module) do
      %{form: form} -> form
      _ -> nil
    end
  end

  @spec merge_domain_defaults(Spark.Dsl.t(), map() | nil) :: Spark.Dsl.t()
  defp merge_domain_defaults(dsl_state, nil), do: dsl_state

  defp merge_domain_defaults(dsl_state, defaults) do
    Enum.reduce(@domain_mappings, dsl_state, fn mapping, acc ->
      apply_domain_mapping(acc, defaults, mapping)
    end)
  end

  @spec apply_domain_mapping(Spark.Dsl.t(), map(), tuple()) :: Spark.Dsl.t()
  defp apply_domain_mapping(dsl_state, defaults, {path_suffix, key}) do
    path = @form_path ++ path_suffix
    maybe_set_from_domain(dsl_state, path, key, defaults[key])
  end

  defp apply_domain_mapping(dsl_state, defaults, {path_suffix, key, domain_path}) do
    path = @form_path ++ path_suffix
    domain_value = get_in(defaults, domain_path)
    maybe_set_from_domain(dsl_state, path, key, domain_value)
  end

  @spec maybe_set_from_domain(Spark.Dsl.t(), [atom()], atom(), term()) :: Spark.Dsl.t()
  defp maybe_set_from_domain(dsl_state, _path, _key, nil), do: dsl_state

  defp maybe_set_from_domain(dsl_state, path, key, domain_value) do
    if get_opt(dsl_state, path, key) == nil,
      do: set_opt(dsl_state, path, key, domain_value),
      else: dsl_state
  end

  @spec merge_identity_defaults(Spark.Dsl.t(), module()) :: Spark.Dsl.t()
  defp merge_identity_defaults(dsl_state, module) do
    identity_path = @form_path ++ [:identity]

    dsl_state
    |> maybe_set_identity_name(identity_path, module)
    |> maybe_set_stream_name(identity_path)
  end

  @spec maybe_set_identity_name(Spark.Dsl.t(), [atom()], module()) :: Spark.Dsl.t()
  defp maybe_set_identity_name(dsl_state, path, module) do
    case get_opt(dsl_state, path, :name) do
      nil ->
        module
        |> module_to_snake("_form")
        |> String.to_atom()
        |> then(&set_opt(dsl_state, path, :name, &1))

      _ ->
        dsl_state
    end
  end

  @spec maybe_set_stream_name(Spark.Dsl.t(), [atom()]) :: Spark.Dsl.t()
  defp maybe_set_stream_name(dsl_state, path) do
    case get_opt(dsl_state, path, :stream_name) do
      nil ->
        get_opt(dsl_state, path, :name)
        |> then(&set_opt(dsl_state, path, :stream_name, String.to_atom("#{&1}_stream")))

      _ ->
        dsl_state
    end
  end

  @spec merge_master_check_default(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp merge_master_check_default(dsl_state) do
    source_path = @form_path ++ [:source]

    case get_opt(dsl_state, source_path, :master_check) do
      nil ->
        Transformer.persist(
          dsl_state,
          :mishka_gervaz_form_default_master_check,
          {MishkaGervaz.Defaults, :default_master_check, [:site_id]}
        )

      _ ->
        dsl_state
    end
  end
end

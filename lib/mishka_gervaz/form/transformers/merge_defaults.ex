defmodule MishkaGervaz.Form.Transformers.MergeDefaults do
  @moduledoc """
  Fills the form DSL state with sensible defaults before downstream
  transformers run.

  Three responsibilities, applied in order:

    1. **Domain inheritance** — copy each key in `@domain_mappings`
       from the resource's domain into the resource's DSL state when
       the resource hasn't set it explicitly. Resource overrides win.

    2. **Identity defaults** — derive `identity.name` from the resource
       module name (snake-cased, suffixed with `_form`) when not set,
       and derive `identity.stream_name` as `<name>_stream`.

    3. **Master-check fallback** — when neither resource nor domain
       defines `master_check`, persist a fallback MFA pointing to
       `MishkaGervaz.Helpers.master_user?/1`.

  ## Pipeline

  See `transform/1` — every stage takes the DSL state as the first
  argument so the entry point reads top-down.

  See `MishkaGervaz.Form.Transformers.ResolveFields` and
  `MishkaGervaz.Form.Transformers.BuildRuntimeConfig` for the
  downstream transformers that consume these defaults.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  import MishkaGervaz.Helpers, only: [module_to_snake: 2]
  import MishkaGervaz.Table.Transformers.Helpers

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
    domain_defaults = resolve_domain_defaults(module)

    dsl_state =
      dsl_state
      |> merge_domain_defaults(domain_defaults)
      |> merge_identity_defaults(module)
      |> merge_master_check_default()

    {:ok, dsl_state}
  end

  @spec resolve_domain_defaults(module()) :: map() | nil
  defp resolve_domain_defaults(module) do
    case get_domain_config(module) do
      %{form: form} -> form
      _ -> nil
    end
  end

  @spec merge_domain_defaults(Spark.Dsl.t(), map() | nil) :: Spark.Dsl.t()
  defp merge_domain_defaults(dsl_state, nil), do: dsl_state

  defp merge_domain_defaults(dsl_state, defaults) do
    Enum.reduce(@domain_mappings, dsl_state, fn {path_suffix, key}, acc ->
      maybe_set_from_domain(acc, @form_path ++ path_suffix, key, defaults[key])
    end)
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
        derived = module |> module_to_snake("_form") |> String.to_atom()
        set_opt(dsl_state, path, :name, derived)

      _ ->
        dsl_state
    end
  end

  @spec maybe_set_stream_name(Spark.Dsl.t(), [atom()]) :: Spark.Dsl.t()
  defp maybe_set_stream_name(dsl_state, path) do
    case get_opt(dsl_state, path, :stream_name) do
      nil ->
        derived = String.to_atom("#{get_opt(dsl_state, path, :name)}_stream")
        set_opt(dsl_state, path, :stream_name, derived)

      _ ->
        dsl_state
    end
  end

  @spec merge_master_check_default(Spark.Dsl.t()) :: Spark.Dsl.t()
  defp merge_master_check_default(dsl_state) do
    case get_opt(dsl_state, @form_path ++ [:source], :master_check) do
      nil ->
        Transformer.persist(
          dsl_state,
          :mishka_gervaz_form_default_master_check,
          {MishkaGervaz.Helpers, :master_user?, []}
        )

      _ ->
        dsl_state
    end
  end
end

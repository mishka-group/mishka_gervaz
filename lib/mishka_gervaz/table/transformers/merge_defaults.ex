defmodule MishkaGervaz.Table.Transformers.MergeDefaults do
  @moduledoc """
  Merges default values into the DSL configuration.

  This transformer fills in sensible defaults for unspecified options,
  including:

  - Inheriting defaults from the domain (if using `MishkaGervaz.Domain`)
  - Deriving `identity.name` from the resource module name
  - Generating `identity.stream_name` if not specified

  If a domain declares `master_check`, it flows to the resource's
  `source.master_check`. If neither domain nor resource declares one,
  `Info.Table` leaves it `nil`; callers should check for `nil` (no
  fallback is injected, unlike the form side which falls back to
  `MishkaGervaz.Helpers.master_user?/1` via `Info.Form`).

  See `MishkaGervaz.Table.Transformers.BuildDomainConfig` (upstream),
  `MishkaGervaz.Table.Transformers.ResolveColumns` (downstream),
  `MishkaGervaz.Table.Transformers.BuildRuntimeConfig` (final),
  `MishkaGervaz.Table.Transformers.Helpers`, and the form-side
  counterpart `MishkaGervaz.Form.Transformers.MergeDefaults`.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  import MishkaGervaz.Table.Transformers.Helpers
  import MishkaGervaz.Helpers, only: [module_to_snake: 2]

  @table_path [:mishka_gervaz, :table]

  @domain_mappings [
    {[:presentation], :ui_adapter},
    {[:presentation], :ui_adapter_opts},
    {[:source], :actor_key},
    {[:source], :master_check},
    {[:source, :actions], :read, [:actions, :read]},
    {[:source, :actions], :get, [:actions, :get]},
    {[:source, :actions], :destroy, [:actions, :destroy]},
    {[:pagination], :type, [:pagination, :type]},
    {[:pagination], :page_size, [:pagination, :page_size]},
    {[:realtime], :enabled, [:realtime, :enabled]},
    {[:realtime], :pubsub, [:realtime, :pubsub]},
    {[:presentation, :theme], :header_class, [:theme, :header_class]},
    {[:presentation, :theme], :row_class, [:theme, :row_class]},
    {[:presentation, :theme], :border_class, [:theme, :border_class]}
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

    {:ok, dsl_state}
  end

  @spec get_domain_defaults(module()) :: map() | nil
  defp get_domain_defaults(module) do
    case get_domain_config(module) do
      %{table: table} -> table
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
    path = @table_path ++ path_suffix
    maybe_set_from_domain(dsl_state, path, key, defaults[key])
  end

  defp apply_domain_mapping(dsl_state, defaults, {path_suffix, key, domain_path}) do
    path = @table_path ++ path_suffix
    domain_value = get_in(defaults, domain_path)
    maybe_set_from_domain(dsl_state, path, key, domain_value)
  end

  @spec maybe_set_from_domain(Spark.Dsl.t(), [atom()], atom(), term()) :: Spark.Dsl.t()
  defp maybe_set_from_domain(dsl_state, _path, _key, nil), do: dsl_state

  defp maybe_set_from_domain(dsl_state, path, key, domain_value) do
    if get_opt(dsl_state, path, key) == nil do
      set_opt(dsl_state, path, key, domain_value)
    else
      dsl_state
    end
  end

  @spec merge_identity_defaults(Spark.Dsl.t(), module()) :: Spark.Dsl.t()
  defp merge_identity_defaults(dsl_state, module) do
    identity_path = @table_path ++ [:identity]

    dsl_state
    |> maybe_set_identity_name(identity_path, module)
    |> maybe_set_stream_name(identity_path)
  end

  @spec maybe_set_identity_name(Spark.Dsl.t(), [atom()], module()) :: Spark.Dsl.t()
  defp maybe_set_identity_name(dsl_state, path, module) do
    case get_opt(dsl_state, path, :name) do
      nil ->
        derived_name = module |> module_to_snake("_table") |> String.to_atom()
        set_opt(dsl_state, path, :name, derived_name)

      _ ->
        dsl_state
    end
  end

  @spec maybe_set_stream_name(Spark.Dsl.t(), [atom()]) :: Spark.Dsl.t()
  defp maybe_set_stream_name(dsl_state, path) do
    case get_opt(dsl_state, path, :stream_name) do
      nil ->
        name = get_opt(dsl_state, path, :name)
        set_opt(dsl_state, path, :stream_name, String.to_atom("#{name}_stream"))

      _ ->
        dsl_state
    end
  end
end

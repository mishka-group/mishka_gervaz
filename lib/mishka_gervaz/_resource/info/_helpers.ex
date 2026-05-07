defmodule MishkaGervaz.Resource.Info.Helpers do
  @moduledoc """
  Shared utilities for `MishkaGervaz.Resource.Info.{Form,Table}`.

  These helpers absorb the repeating shapes used by both info modules:
  field-with-default lookups on the merged config, preload-source
  extraction, and domain-defaults retrieval.
  """

  alias Spark.Dsl.Extension

  @doc """
  Fetch a key from a possibly-nil map, returning `default` when the key is
  missing or the value is nil.
  """
  @spec map_get(map() | nil, atom(), term()) :: term()
  def map_get(nil, _key, default), do: default

  def map_get(map, key, default) do
    case map do
      %{^key => value} when not is_nil(value) -> value
      _ -> default
    end
  end

  @doc """
  Unwrap a preload entry to its source atom. Preloads can be plain atoms or
  `{source, alias}` tuples — this returns the atom either way.
  """
  @spec extract_preload_source(atom() | {atom(), atom()}) :: atom()
  def extract_preload_source({source, _alias}), do: source
  def extract_preload_source(source) when is_atom(source), do: source

  @doc """
  Look up the Ash domain for a resource.
  """
  @spec get_domain(module()) :: {:ok, module()} | :error
  def get_domain(resource) do
    case Ash.Resource.Info.domain(resource) do
      nil -> :error
      domain -> {:ok, domain}
    end
  end

  @doc """
  Fetch the domain-side defaults map for a given section (`:form` or `:table`).
  Returns `%{}` when the resource has no domain or the domain has no
  `mishka_gervaz` block.
  """
  @spec get_domain_defaults(module(), atom()) :: map()
  def get_domain_defaults(resource, section) do
    with {:ok, domain} <- get_domain(resource),
         config when not is_nil(config) <-
           Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      Map.get(config, section, %{})
    else
      _ -> %{}
    end
  end
end

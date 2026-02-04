defmodule MishkaGervaz.Table.Transformers.Helpers do
  @moduledoc """
  Shared helper functions for MishkaGervaz transformers.

  These functions are used across multiple transformers to reduce duplication
  and provide consistent DSL state manipulation.
  """

  alias Spark.Dsl.Transformer

  @doc """
  Gets an option from the DSL state at the given path.
  """
  @spec get_opt(Spark.Dsl.t(), [atom()], atom(), term()) :: term()
  def get_opt(dsl_state, path, key, default \\ nil),
    do: Transformer.get_option(dsl_state, path, key, default)

  @doc """
  Sets an option in the DSL state at the given path.
  """
  @spec set_opt(Spark.Dsl.t(), [atom()], atom(), term()) :: Spark.Dsl.t()
  def set_opt(dsl_state, path, key, value),
    do: Transformer.set_option(dsl_state, path, key, value)

  @doc """
  Gets entities from the DSL state at the given path, always returning a list.
  """
  @spec get_entities(Spark.Dsl.t(), [atom()]) :: [struct()]
  def get_entities(dsl_state, path),
    do: dsl_state |> Transformer.get_entities(path) |> List.wrap()

  @doc """
  Finds a single entity of the given type at the specified path.
  """
  @spec find_entity(Spark.Dsl.t(), [atom()], module()) :: struct() | nil
  def find_entity(dsl_state, path, type),
    do: dsl_state |> get_entities(path) |> Enum.find(&is_struct(&1, type))

  @doc """
  Filters entities by struct type.
  """
  @spec filter_by_type([struct()], module()) :: [struct()]
  def filter_by_type(entities, type),
    do: Enum.filter(entities, &is_struct(&1, type))

  @doc """
  Safely gets the domain module for a resource.
  """
  @spec safe_domain(module()) :: {:ok, module()} | :error
  def safe_domain(module) do
    {:ok, Ash.Resource.Info.domain(module)}
  rescue
    _ -> :error
  end

  @doc """
  Safely gets the MishkaGervaz domain config from a domain module.
  """
  @spec safe_domain_config(module()) :: map() | nil
  def safe_domain_config(domain) do
    Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config)
  rescue
    _ -> nil
  end

  @doc """
  Gets the full domain config for a resource module.
  """
  @spec get_domain_config(module()) :: map() | nil
  def get_domain_config(module) do
    with {:ok, domain} <- safe_domain(module),
         config when not is_nil(config) <- safe_domain_config(domain) do
      config
    else
      _ -> nil
    end
  end

  @doc """
  Checks if a module has a specific Spark extension.
  """
  @spec has_extension?(module(), module()) :: boolean()
  def has_extension?(module, extension) do
    extension in Spark.extensions(module)
  rescue
    _ -> false
  end

  @doc """
  Checks if any value in the list is not nil.
  """
  @spec any_set?([term()]) :: boolean()
  def any_set?(values), do: Enum.any?(values, &(&1 != nil))

  @doc """
  Returns the default if value is nil, otherwise returns the value.
  """
  @spec default_if_nil(term(), term()) :: term()
  def default_if_nil(nil, default), do: default
  def default_if_nil(value, _default), do: value

  @doc """
  Extracts a nested entity from a list or single value.
  Spark stores nested entities as lists.
  """
  @spec extract_nested_entity(list() | struct() | nil, module()) :: struct() | nil
  def extract_nested_entity([entity | _], type) when is_struct(entity, type), do: entity
  def extract_nested_entity(entity, type) when is_struct(entity, type), do: entity
  def extract_nested_entity(_, _), do: nil
end

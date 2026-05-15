defmodule MishkaGervaz.Domain.Info.Table do
  @moduledoc """
  Table-specific introspection for domains using `MishkaGervaz.Domain`.

  ## Usage

      # Get the inherited table defaults
      defaults = MishkaGervaz.Domain.Info.Table.defaults(MyDomain)

      # Get default pagination
      pagination = MishkaGervaz.Domain.Info.Table.pagination(MyDomain)

      # Get navigation (domain-wide, not table-specific) — see Domain.Info.menu_groups/1
  """

  use Spark.InfoGenerator,
    extension: MishkaGervaz.Domain,
    sections: [:mishka_gervaz]

  alias Spark.Dsl.Extension

  import MishkaGervaz.Helpers, only: [map_get: 3]

  @doc """
  Get the full domain table configuration.
  """
  @spec config(module()) :: map() | nil
  def config(domain), do: Extension.get_persisted(domain, :mishka_gervaz_domain_config)

  @doc """
  Get the inherited table defaults for a domain.

  These settings are inherited by all resources in the domain.
  """
  @spec defaults(module()) :: map()
  def defaults(domain), do: map_get(config(domain), :table, %{})

  @doc """
  Get the UI adapter.
  """
  @spec ui_adapter(module()) :: module()
  def ui_adapter(domain),
    do: defaults(domain)[:ui_adapter] || MishkaGervaz.UIAdapters.Tailwind

  @doc """
  Get the UI adapter options.
  """
  @spec ui_adapter_opts(module()) :: keyword()
  def ui_adapter_opts(domain), do: defaults(domain)[:ui_adapter_opts] || []

  @doc """
  Get the actor key.
  """
  @spec actor_key(module()) :: atom()
  def actor_key(domain), do: defaults(domain)[:actor_key] || :current_user

  @doc """
  Get the master_check function.
  """
  @spec master_check(module()) :: (any() -> boolean()) | nil
  def master_check(domain), do: defaults(domain)[:master_check]

  @doc """
  Get the pagination config.
  """
  @spec pagination(module()) :: map() | nil
  def pagination(domain), do: defaults(domain)[:pagination]

  @doc """
  Get the default page size.
  """
  @spec page_size(module()) :: pos_integer() | nil
  def page_size(domain), do: map_get(pagination(domain), :page_size, nil)

  @doc """
  Get the default page size options.
  """
  @spec page_size_options(module()) :: [pos_integer()] | nil
  def page_size_options(domain), do: map_get(pagination(domain), :page_size_options, nil)

  @doc """
  Get the default max page size.
  """
  @spec max_page_size(module()) :: pos_integer() | nil
  def max_page_size(domain), do: map_get(pagination(domain), :max_page_size, nil)

  @doc """
  Get the realtime config.
  """
  @spec realtime(module()) :: map() | nil
  def realtime(domain), do: defaults(domain)[:realtime]

  @doc """
  Get the theme config.
  """
  @spec theme(module()) :: map() | nil
  def theme(domain), do: defaults(domain)[:theme]

  @doc """
  Get the actions config.
  """
  @spec actions(module()) :: map() | nil
  def actions(domain), do: defaults(domain)[:actions]

  @doc """
  Get the refresh config.
  """
  @spec refresh(module()) :: map() | nil
  def refresh(domain), do: defaults(domain)[:refresh]

  @doc """
  Get the URL sync config.
  """
  @spec url_sync(module()) :: map() | nil
  def url_sync(domain), do: defaults(domain)[:url_sync]
end

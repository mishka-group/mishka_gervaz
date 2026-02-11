defmodule MishkaGervaz.Domain.Info.Table do
  @moduledoc """
  Table-specific introspection for domains using `MishkaGervaz.Domain`.

  ## Usage

      # Get table config
      table = MishkaGervaz.Domain.Info.Table.table(MyDomain)

      # Get default pagination
      pagination = MishkaGervaz.Domain.Info.Table.pagination(MyDomain)

      # Get menu groups
      groups = MishkaGervaz.Domain.Info.Table.menu_groups(MyDomain)
  """

  use Spark.InfoGenerator,
    extension: MishkaGervaz.Domain,
    sections: [:mishka_gervaz]

  alias Spark.Dsl.Extension

  @doc """
  Get the full domain table configuration.
  """
  @spec config(module()) :: map() | nil
  def config(domain), do: Extension.get_persisted(domain, :mishka_gervaz_domain_config)

  @doc """
  Get the table configuration for a domain.

  These settings are inherited by all resources in the domain.
  """
  @spec table(module()) :: map()
  def table(domain) do
    case config(domain) do
      %{table: table} -> table
      _ -> %{}
    end
  end

  @doc false
  @spec defaults(module()) :: map()
  def defaults(domain), do: table(domain)

  @doc """
  Get the navigation configuration for a domain.
  Returns nil if navigation is not defined.
  """
  @spec navigation(module()) :: map() | nil
  def navigation(domain) do
    case config(domain) do
      %{navigation: navigation} -> navigation
      _ -> nil
    end
  end

  @doc """
  Get the menu groups for a domain.
  """
  @spec menu_groups(module()) :: [map()]
  def menu_groups(domain) do
    case navigation(domain) do
      %{menu_groups: groups} -> groups
      nil -> []
      _ -> []
    end
  end

  @doc """
  Get the UI adapter.
  """
  @spec ui_adapter(module()) :: module()
  def ui_adapter(domain),
    do: table(domain)[:ui_adapter] || MishkaGervaz.UIAdapters.Tailwind

  @doc """
  Get the UI adapter options.
  """
  @spec ui_adapter_opts(module()) :: keyword()
  def ui_adapter_opts(domain), do: table(domain)[:ui_adapter_opts] || []

  @doc """
  Get the actor key.
  """
  @spec actor_key(module()) :: atom()
  def actor_key(domain), do: table(domain)[:actor_key] || :current_user

  @doc """
  Get the master_check function.
  """
  @spec master_check(module()) :: (any() -> boolean()) | nil
  def master_check(domain), do: table(domain)[:master_check]

  @doc """
  Get the pagination config.
  """
  @spec pagination(module()) :: map() | nil
  def pagination(domain), do: table(domain)[:pagination]

  @doc """
  Get the realtime config.
  """
  @spec realtime(module()) :: map() | nil
  def realtime(domain), do: table(domain)[:realtime]

  @doc """
  Get the theme config.
  """
  @spec theme(module()) :: map() | nil
  def theme(domain), do: table(domain)[:theme]

  @doc """
  Get the actions config.
  """
  @spec actions(module()) :: map() | nil
  def actions(domain), do: table(domain)[:actions]

  @doc """
  Get the refresh config.
  """
  @spec refresh(module()) :: map() | nil
  def refresh(domain), do: table(domain)[:refresh]

  @doc """
  Get the URL sync config.
  """
  @spec url_sync(module()) :: map() | nil
  def url_sync(domain), do: table(domain)[:url_sync]
end

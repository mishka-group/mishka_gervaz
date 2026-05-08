defmodule MishkaGervaz.Domain.Info.Form do
  @moduledoc """
  Form-specific introspection for domains using `MishkaGervaz.Domain`.

  ## Usage

      # Get the inherited form defaults
      defaults = MishkaGervaz.Domain.Info.Form.defaults(MyDomain)

      # Get default form UI adapter
      adapter = MishkaGervaz.Domain.Info.Form.ui_adapter(MyDomain)

      # Get default form actions
      actions = MishkaGervaz.Domain.Info.Form.actions(MyDomain)
  """

  use Spark.InfoGenerator,
    extension: MishkaGervaz.Domain,
    sections: [:mishka_gervaz]

  alias Spark.Dsl.Extension

  import MishkaGervaz.Helpers, only: [map_get: 3]

  @doc """
  Get the full domain configuration.
  """
  @spec config(module()) :: map() | nil
  def config(domain), do: Extension.get_persisted(domain, :mishka_gervaz_domain_config)

  @doc """
  Get the inherited form defaults for a domain.

  These settings are inherited by all resources in the domain.
  """
  @spec defaults(module()) :: map()
  def defaults(domain) do
    case map_get(config(domain), :form, %{}) do
      form when is_map(form) -> form
      _ -> %{}
    end
  end

  @doc """
  Get the form UI adapter.
  """
  @spec ui_adapter(module()) :: module() | nil
  def ui_adapter(domain), do: defaults(domain)[:ui_adapter]

  @doc """
  Get the form UI adapter options.
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
  Get the form actions config.
  """
  @spec actions(module()) :: map() | nil
  def actions(domain), do: defaults(domain)[:actions]

  @doc """
  Get the form theme config.
  """
  @spec theme(module()) :: map() | nil
  def theme(domain), do: defaults(domain)[:theme]

  @doc """
  Get the form layout config.
  """
  @spec layout(module()) :: map() | nil
  def layout(domain), do: defaults(domain)[:layout]

  @doc """
  Get the form template.
  """
  @spec template(module()) :: module() | nil
  def template(domain), do: defaults(domain)[:template]

  @doc """
  Get the form features.
  """
  @spec features(module()) :: :all | [atom()] | nil
  def features(domain), do: defaults(domain)[:features]

  @doc """
  Get the form submit config.
  """
  @spec submit(module()) :: map() | nil
  def submit(domain), do: defaults(domain)[:submit]
end

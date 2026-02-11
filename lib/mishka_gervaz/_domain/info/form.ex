defmodule MishkaGervaz.Domain.Info.Form do
  @moduledoc """
  Form-specific introspection for domains using `MishkaGervaz.Domain`.

  ## Usage

      # Get form config
      form = MishkaGervaz.Domain.Info.Form.form(MyDomain)

      # Get default form UI adapter
      adapter = MishkaGervaz.Domain.Info.Form.ui_adapter(MyDomain)

      # Get default form actions
      actions = MishkaGervaz.Domain.Info.Form.actions(MyDomain)
  """

  use Spark.InfoGenerator,
    extension: MishkaGervaz.Domain,
    sections: [:mishka_gervaz]

  alias Spark.Dsl.Extension

  @doc """
  Get the full domain configuration.
  """
  @spec config(module()) :: map() | nil
  def config(domain), do: Extension.get_persisted(domain, :mishka_gervaz_domain_config)

  @doc """
  Get the form configuration for a domain.

  These settings are inherited by all resources in the domain.
  """
  @spec form(module()) :: map()
  def form(domain) do
    case config(domain) do
      %{form: form} when is_map(form) -> form
      _ -> %{}
    end
  end

  @doc false
  @spec defaults(module()) :: map()
  def defaults(domain), do: form(domain)

  @doc """
  Get the form UI adapter.
  """
  @spec ui_adapter(module()) :: module() | nil
  def ui_adapter(domain), do: form(domain)[:ui_adapter]

  @doc """
  Get the form UI adapter options.
  """
  @spec ui_adapter_opts(module()) :: keyword()
  def ui_adapter_opts(domain), do: form(domain)[:ui_adapter_opts] || []

  @doc """
  Get the actor key.
  """
  @spec actor_key(module()) :: atom()
  def actor_key(domain), do: form(domain)[:actor_key] || :current_user

  @doc """
  Get the master_check function.
  """
  @spec master_check(module()) :: (any() -> boolean()) | nil
  def master_check(domain), do: form(domain)[:master_check]

  @doc """
  Get the form actions config.
  """
  @spec actions(module()) :: map() | nil
  def actions(domain), do: form(domain)[:actions]

  @doc """
  Get the form theme config.
  """
  @spec theme(module()) :: map() | nil
  def theme(domain), do: form(domain)[:theme]

  @doc """
  Get the form layout config.
  """
  @spec layout(module()) :: map() | nil
  def layout(domain), do: form(domain)[:layout]
end

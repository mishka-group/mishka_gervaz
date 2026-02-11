defmodule MishkaGervaz.Form.Transformers.BuildDomainConfig do
  @moduledoc """
  Builds the domain-level form configuration from the DSL state.

  Persists form defaults under the `:form` key within `:mishka_gervaz_domain_config`.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  import MishkaGervaz.Table.Transformers.Helpers

  @form_path [:mishka_gervaz, :form]

  @theme_defaults %{
    form_class: nil,
    field_class: nil,
    label_class: nil,
    error_class: nil,
    extra: %{}
  }

  @layout_defaults %{
    navigation: :sequential,
    persistence: :none,
    columns: 1
  }

  @impl true
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl_state) do
    form_config = build_form(dsl_state)

    existing = Transformer.get_persisted(dsl_state, :mishka_gervaz_domain_config, %{})
    config = Map.put(existing, :form, form_config)

    {:ok, Transformer.persist(dsl_state, :mishka_gervaz_domain_config, config)}
  end

  @spec build_form(Spark.Dsl.t()) :: map()
  defp build_form(dsl_state) do
    %{
      ui_adapter: get_opt(dsl_state, @form_path, :ui_adapter),
      ui_adapter_opts: get_opt(dsl_state, @form_path, :ui_adapter_opts, []),
      actor_key: get_opt(dsl_state, @form_path, :actor_key, :current_user),
      master_check: get_opt(dsl_state, @form_path, :master_check),
      actions: build_actions(dsl_state),
      theme: build_section(dsl_state, :theme, @theme_defaults),
      layout: build_section(dsl_state, :layout, @layout_defaults)
    }
  end

  @spec build_actions(Spark.Dsl.t()) :: map()
  defp build_actions(dsl_state) do
    path = @form_path ++ [:actions]

    %{
      create: get_opt(dsl_state, path, :create, {:master_create, :create}),
      update: get_opt(dsl_state, path, :update, {:master_update, :update}),
      read: get_opt(dsl_state, path, :read, {:master_get, :read})
    }
  end

  @spec build_section(Spark.Dsl.t(), atom(), map()) :: map() | nil
  defp build_section(dsl_state, section, defaults) do
    path = @form_path ++ [section]
    keys = Map.keys(defaults)
    values = Map.new(keys, &{&1, get_opt(dsl_state, path, &1)})

    if Enum.any?(values, fn {_, v} -> v != nil end) do
      Map.merge(defaults, reject_nil_values(values))
    else
      nil
    end
  end

  @spec reject_nil_values(map()) :: map()
  defp reject_nil_values(map) do
    Map.reject(map, fn {_, v} -> is_nil(v) end)
  end
end

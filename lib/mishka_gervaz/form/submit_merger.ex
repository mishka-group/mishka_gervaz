defmodule MishkaGervaz.Form.SubmitMerger do
  @moduledoc """
  Resolves the final form `submit` configuration by merging the resource-level
  submit (built from the DSL entity) with the domain-level submit defaults.

  ## Priority rules

    * Resource is the first priority; domain is the second.
    * For each button kind (`:create`, `:update`, `:cancel`):
      - If the resource defines the button, the resource wins. The label
        falls back through resource → domain → hard default for the kind.
      - If the resource does not define the button, the domain button is used.
      - If the resource defines the button with `active: false`, the button is
        suppressed regardless of what the domain provides.
    * `position` follows resource → domain → `:bottom`.
    * `ui` follows resource → domain → `nil`.
    * If neither side defines `submit`, the result is `nil`.
    * If only the domain defines `submit`, its buttons are normalized so that
      missing labels fall back to the hard defaults.

  Both `BuildRuntimeConfig` (compile time) and `Resource.Info.Form` (runtime)
  use this module so the merge logic stays in one place.
  """

  alias MishkaGervaz.Form.Entities.Submit

  @default_labels %{
    create: "Create",
    update: "Save Changes",
    cancel: "Cancel"
  }

  @doc """
  Merges the resource entity (or pre-built map) with the domain submit map.

  Returns the merged map with this shape:

      %{
        create: %{label, active, disabled, restricted, visible} | nil,
        update: %{...} | nil,
        cancel: %{...} | nil,
        position: :top | :bottom | :both,
        ui: map() | nil
      }

  Returns `nil` if neither side defines a `submit` block.
  """
  @spec merge(Submit.t() | map() | nil, map() | nil) :: map() | nil
  def merge(nil, nil), do: nil
  def merge(nil, %{} = domain), do: normalize_domain_only(domain)

  def merge(%Submit{} = resource, domain) do
    %{
      create: merge_button(:create, resource.create, domain_button(domain, :create)),
      update: merge_button(:update, resource.update, domain_button(domain, :update)),
      cancel: merge_button(:cancel, resource.cancel, domain_button(domain, :cancel)),
      position: resource.position || domain_value(domain, :position) || :bottom,
      ui: merged_ui(resource.ui, domain_value(domain, :ui))
    }
  end

  def merge(%{} = resource_map, domain) do
    %{
      create:
        merge_resource_map_button(:create, resource_map[:create], domain_button(domain, :create)),
      update:
        merge_resource_map_button(:update, resource_map[:update], domain_button(domain, :update)),
      cancel:
        merge_resource_map_button(:cancel, resource_map[:cancel], domain_button(domain, :cancel)),
      position: resource_map[:position] || domain_value(domain, :position) || :bottom,
      ui: merged_ui(resource_map[:ui], domain_value(domain, :ui))
    }
  end

  defp normalize_domain_only(domain) do
    %{
      create: domain_only_button(:create, domain[:create]),
      update: domain_only_button(:update, domain[:update]),
      cancel: domain_only_button(:cancel, domain[:cancel]),
      position: domain[:position] || :bottom,
      ui: domain[:ui]
    }
  end

  defp domain_only_button(_kind, nil), do: nil

  defp domain_only_button(kind, %{} = domain_btn) do
    %{
      label: domain_btn[:label] || Map.fetch!(@default_labels, kind),
      active: true,
      disabled: domain_btn[:disabled] || false,
      restricted: domain_btn[:restricted] || false,
      visible: if(is_nil(domain_btn[:visible]), do: true, else: domain_btn[:visible])
    }
  end

  defp merge_button(_kind, nil, nil), do: nil
  defp merge_button(kind, nil, %{} = domain_btn), do: domain_only_button(kind, domain_btn)
  defp merge_button(_kind, %Submit.Button{active: false}, _domain_btn), do: nil

  defp merge_button(kind, %Submit.Button{} = resource_btn, domain_btn) do
    %{
      label: resolve_label(resource_btn.label, domain_btn, kind),
      active: resource_btn.active,
      disabled: resource_btn.disabled,
      restricted: resource_btn.restricted,
      visible: resource_btn.visible
    }
  end

  defp merge_resource_map_button(_kind, nil, nil), do: nil

  defp merge_resource_map_button(kind, nil, %{} = domain_btn),
    do: domain_only_button(kind, domain_btn)

  defp merge_resource_map_button(_kind, %{active: false}, _domain_btn), do: nil

  defp merge_resource_map_button(kind, %{} = resource_btn, domain_btn) do
    %{
      label: resolve_label(resource_btn[:label], domain_btn, kind),
      active: Map.get(resource_btn, :active, true),
      disabled: Map.get(resource_btn, :disabled, false),
      restricted: Map.get(resource_btn, :restricted, false),
      visible: Map.get(resource_btn, :visible, true)
    }
  end

  defp resolve_label(nil, %{} = domain_btn, kind),
    do: domain_btn[:label] || Map.fetch!(@default_labels, kind)

  defp resolve_label(nil, _domain_btn, kind), do: Map.fetch!(@default_labels, kind)
  defp resolve_label(label, _domain_btn, _kind), do: label

  defp domain_button(nil, _kind), do: nil
  defp domain_button(%{} = domain, kind), do: Map.get(domain, kind)

  defp domain_value(nil, _key), do: nil
  defp domain_value(%{} = domain, key), do: Map.get(domain, key)

  defp merged_ui(nil, %{} = domain_ui), do: domain_ui
  defp merged_ui(nil, _), do: nil
  defp merged_ui(%Submit.Ui{} = ui, _), do: submit_ui_to_map(ui)
  defp merged_ui(%{} = ui_map, _), do: ui_map

  defp submit_ui_to_map(%Submit.Ui{} = ui) do
    if any_set?([ui.submit_class, ui.cancel_class, ui.wrapper_class]) or ui.extra != %{} do
      %{
        submit_class: ui.submit_class,
        cancel_class: ui.cancel_class,
        wrapper_class: ui.wrapper_class,
        extra: ui.extra
      }
    else
      nil
    end
  end

  defp any_set?(values), do: Enum.any?(values, &(&1 != nil))
end

defmodule MishkaGervaz.Table.UIAdapters.MediaGallery do
  @moduledoc """
  UI adapter for media gallery template.

  Extends the Tailwind adapter with gallery-specific styling.
  Override only the components that need different appearance in gallery context.
  """

  use MishkaGervaz.Table.Behaviours.UIAdapter,
    fallback: MishkaGervaz.Table.UIAdapters.Tailwind

  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :icon, :string, default: nil

  attr :rest, :global,
    include: ~w(phx-click phx-target phx-value-id phx-value-event phx-value-values data-confirm)

  @doc """
  Gallery-styled button with circular overlay appearance.
  """
  def button(assigns) do
    default_class = "p-2 bg-white rounded-full shadow hover:bg-gray-100"

    assigns =
      assigns
      |> assign(
        :class,
        if(assigns[:class] in [nil, ""], do: default_class, else: assigns[:class])
      )
      |> assign_new(:icon, fn -> nil end)

    ~H"""
    <button
      type="button"
      class={@class}
      title={@label}
      {@rest}
    >
      <.render_icon :if={@icon} name={@icon} class="w-4 h-4" />
      <span :if={!@icon} class="text-xs">{@label}</span>
    </button>
    """
  end

  defp render_icon(assigns) do
    name = assigns[:name] || ""
    class = assigns[:class] || "w-5 h-5"

    if String.starts_with?(name, "hero-") do
      icon_name = String.replace_prefix(name, "hero-", "")
      assigns = %{name: icon_name, class: class}

      ~H"""
      <span class={["hero-#{@name}", @class]}></span>
      """
    else
      assigns = %{class: class}

      ~H"""
      <span class={@class}></span>
      """
    end
  end
end

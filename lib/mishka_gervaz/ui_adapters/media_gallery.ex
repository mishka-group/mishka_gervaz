defmodule MishkaGervaz.UIAdapters.MediaGallery do
  @moduledoc """
  UI adapter for the media gallery template.

  Extends the Tailwind adapter; only `button/1` differs, because a media card's actions are not a
  row of labelled controls — they are the small bordered squares under the file's name, and beside
  them one wide button that says what it does.

  Both are the SAME button. This draws one square and colours it by `variant`, and the label always
  reaches the DOM inside a `.lbl` span; `MishkaGervaz.Table.Templates.MediaGallery` widens the one
  it makes primary and hides the label on the rest. Drawing two shapes here instead would put the
  card's layout in two places, and the template is the one that knows how much room there is.

  Everything else — including the view switcher — falls back to `MishkaGervaz.UIAdapters.Tailwind`.

  Reached through `MishkaGervaz.Table.Templates.MediaGallery.render_item/1`, which swaps to this
  adapter whenever the resource has not named one of its own, so a card carries the same buttons on
  every surface that borrows it — the Media library and the page builder's Assets sheet alike.
  """

  use MishkaGervaz.Behaviours.UIAdapter,
    fallback: MishkaGervaz.UIAdapters.Tailwind

  @square "grid size-[30px] flex-none place-items-center rounded-[9px] border transition-colors " <>
            "phx-click-loading:pointer-events-none phx-click-loading:opacity-70"

  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :icon, :string, default: nil
  attr :variant, :atom, default: :default

  attr :rest, :global,
    include: ~w(phx-click phx-target phx-value-id phx-value-event phx-value-values data-confirm)

  @doc """
  A card action, drawn as a bordered square around a 15px glyph, dimmed while its click is pending
  (`phx-click-loading:`, see `MishkaGervaz.UIAdapters.Tailwind`).

  A `:destroy` variant is tinted red — an archive or a permanent delete should not look like the
  three buttons next to it. An action that declares its own `ui do class … end` keeps it; that is
  the escape hatch for a design this square does not fit.
  """
  def button(assigns) do
    assigns =
      assigns
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:variant, fn -> :default end)

    assigns =
      assign(
        assigns,
        :class,
        if(assigns[:class] in [nil, ""],
          do: default_class(assigns[:variant]),
          else: assigns.class
        )
      )

    ~H"""
    <button type="button" class={@class} title={@label} {@rest}>
      <.icon :if={@icon} name={@icon} class="size-[15px]" />
      <span :if={@label not in [nil, ""]} class="lbl">{@label}</span>
    </button>
    """
  end

  defp default_class(:destroy),
    do:
      @square <>
        " border-[#f3ddd9] bg-[#fdf4f3] text-[#c0392b] hover:border-[#e8bfb8] hover:bg-[#fbeae7]"

  defp default_class(_variant),
    do:
      @square <>
        " border-[#ecebe6] bg-white text-[#8a877f] hover:border-[#dcdbf5] hover:text-[#4f4bcc]"
end

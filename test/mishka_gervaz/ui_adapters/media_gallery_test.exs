defmodule MishkaGervaz.UIAdapters.MediaGalleryTest do
  @moduledoc """
  The one button a media card draws, and the three things it has to get right.

  The template widens whichever action it makes primary, so the label has to be IN THE DOM even on
  the squares that hide it — a button that only renders its label when it has no icon can never be
  the wide one. The rest is colour: a destroy is not the same button as a preview.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.UIAdapters.MediaGallery

  defp button(assigns) do
    %{__changed__: nil}
    |> Map.merge(assigns)
    |> MediaGallery.button()
    |> rendered_to_string()
  end

  test "the label is always in the DOM, next to the icon" do
    html = button(%{label: "Edit", icon: "hero-pencil"})

    assert html =~ ~s(<span class="lbl">Edit</span>)
    assert html =~ "hero-pencil"
    assert html =~ ~s(title="Edit")
  end

  test "a plain action is a neutral bordered square" do
    html = button(%{label: "Preview", icon: "hero-eye"})

    assert html =~ "size-[30px]"
    assert html =~ "border-[#ecebe6]"
    refute html =~ "text-[#c0392b]"
  end

  test "a destroy is tinted red so it does not read as its neighbours" do
    html = button(%{label: "Archive", icon: "hero-archive-box", variant: :destroy})

    assert html =~ "text-[#c0392b]"
    assert html =~ "bg-[#fdf4f3]"
    assert html =~ "size-[30px]"

    refute html =~ "bg-white",
           "two background utilities on one button are settled by stylesheet order, not class order"
  end

  # `ui do class … end` IS THE ESCAPE HATCH. A page that draws its own shape must not have this
  # one merged underneath it.
  test "an action that brings its own class keeps it whole" do
    html = button(%{label: "Use", icon: "hero-arrow-down-on-square", class: "my-own-button"})

    assert html =~ ~s(class="my-own-button")
    refute html =~ "size-[30px]"
  end

  test "every square dims and stops taking clicks while its click is pending" do
    for variant <- [:default, :destroy] do
      html = button(%{label: "Edit", icon: "hero-pencil", variant: variant})

      assert html =~ "phx-click-loading:opacity-70", inspect(variant)
      assert html =~ "phx-click-loading:pointer-events-none", inspect(variant)
    end
  end

  test "an iconless button is still a button" do
    html = button(%{label: "Restore"})

    assert html =~ ~s(<span class="lbl">Restore</span>)
    refute html =~ "<svg"
  end
end

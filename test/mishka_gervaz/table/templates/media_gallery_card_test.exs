defmodule MishkaGervaz.Table.Templates.MediaGalleryCardTest do
  @moduledoc """
  The media card's layout contract.

  Two things keep being got wrong by hand and are pinned here: WHICH CORNER each overlay sits in,
  and WHICH ACTION gets which treatment — the star over the thumbnail, the one wide labelled
  button, the squares beside it. The split is a plain function, so it is tested as one; the corners
  need a mounted LiveComponent and a loaded page to render, so those are asserted against the
  source, at the line that makes the decision.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Templates.MediaGallery

  @source File.read!("lib/mishka_gervaz/table/templates/media_gallery.ex")

  @actions [
    %{name: :preview},
    %{name: :edit, type: :edit},
    %{name: :toggle_featured, ui: %{icon: "hero-star"}},
    %{name: :delete, type: :destroy}
  ]

  describe "split_actions/3" do
    test "the star leaves the row, the edit becomes the wide one, the rest stay squares" do
      groups = MediaGallery.split_actions(@actions, %{})

      assert Enum.map(groups.overlay, & &1.name) == [:toggle_featured]
      assert Enum.map(groups.primary, & &1.name) == [:edit]
      assert Enum.map(groups.secondary, & &1.name) == [:preview, :delete]
    end

    test "a resource whose actions are named differently says so" do
      static = %{template_options: [overlay_action: :preview, primary_action: :delete]}
      groups = MediaGallery.split_actions(@actions, static)

      assert Enum.map(groups.overlay, & &1.name) == [:preview]
      assert Enum.map(groups.primary, & &1.name) == [:delete]
      assert Enum.map(groups.secondary, & &1.name) == [:edit, :toggle_featured]
    end

    # A LAYOUT IS ALREADY AN ANSWER to where the actions go. Promoting one out of it would draw an
    # action the layout has parked in a dropdown twice — once as the card's wide button, once in
    # the menu.
    test "a layout that places an action is left alone" do
      static = %{row_actions_layout: [inline: [:edit], dropdown: [:more]]}
      groups = MediaGallery.split_actions(@actions, static)

      assert groups.overlay == []
      assert groups.primary == []
      assert groups.secondary == @actions
    end

    # EVERY resource with row actions has a layout map — the DSL builds one from its defaults — so
    # "a layout exists" is not the question. Reading it as one left the media page drawing four
    # identical squares: no star over the thumbnail, no wide Edit, every label hidden.
    test "an empty layout is not an answer, and the split still happens" do
      static = %{
        row_actions_layout: [position: :end, sticky: true, inline: [], dropdown: []],
        row_action_dropdowns: []
      }

      groups = MediaGallery.split_actions(@actions, static)

      assert Enum.map(groups.overlay, & &1.name) == [:toggle_featured]
      assert Enum.map(groups.primary, & &1.name) == [:edit]
    end

    test "a dropdown alone is enough to leave the row alone" do
      static = %{
        row_actions_layout: [inline: [], dropdown: [:more]],
        row_action_dropdowns: [%{name: :more, items: []}]
      }

      assert MediaGallery.split_actions(@actions, static).secondary == @actions
    end

    test "a card with nothing to promote still renders its squares" do
      groups = MediaGallery.split_actions([%{name: :preview}], %{})

      assert groups.overlay == []
      assert groups.primary == []
      assert Enum.map(groups.secondary, & &1.name) == [:preview]
    end

    test "the star fills in on a featured file and stays hollow otherwise" do
      featured = MediaGallery.split_actions(@actions, %{}, true)
      plain = MediaGallery.split_actions(@actions, %{}, false)

      assert [%{ui: %{icon: "hero-star-solid"}}] = featured.overlay
      assert [%{ui: %{icon: "hero-star"}}] = plain.overlay
    end

    test "filling the star leaves every other action untouched" do
      featured = MediaGallery.split_actions(@actions, %{}, true)

      assert featured.primary == [%{name: :edit, type: :edit}]
      assert featured.secondary == [%{name: :preview}, %{name: :delete, type: :destroy}]
    end
  end

  describe "the card's corners" do
    # A CHECKBOX IS ALWAYS TOP-LEFT and a reader's hand goes there. Anything else in that corner is
    # something they have to move past to select.
    test "selection is top-left" do
      assert @source =~ ~s(class="absolute start-[10px] top-[10px] z-20")
    end

    test "the format badge is top-right" do
      assert @source =~ ~s(class="absolute end-[10px] top-[10px] rounded-md bg-white/85)
    end

    # The star used to share the top-right with nothing; now the badge owns that corner and the star
    # takes the one that is still free.
    test "the featured star is out of the badge's corner" do
      assert @source =~ ~s("absolute bottom-2 end-2 z-20 grid size-7)
      refute @source =~ ~s("absolute end-2 top-2 z-20 grid size-7)
    end
  end

  describe "the actions" do
    # A HOVER OVERLAY IS NOT AN AFFORDANCE ON A TOUCH SCREEN, and it covers the thumbnail the reader
    # is looking at to decide which file this is.
    test "are a row under the meta, not an overlay over the thumbnail" do
      assert @source =~
               ~s(<div\n          :if={@primary_actions != [] or @secondary_actions != []}\n          class="mt-3 flex items-center)

      refute @source =~ "group-hover:bg-[#17161a]/25",
             "the hover overlay is gone, so a delete is not one stray cursor away"
    end

    test "they are still Gervaz's own, not hand-drawn buttons" do
      assert @source =~ "<Shared.render_row_actions"
    end

    # `expand` HAS NO HANDLER — not in the table's events, not in any page that mounts one — so the
    # click fell through to the parent LiveView as `{:table_event, "expand", …}` and crashed it.
    # It also swallowed clicks meant for the star that now sits over the same thumbnail.
    test "the thumbnail no longer pushes an event nothing handles" do
      refute @source =~ ~s(phx-click="expand")
    end
  end

  test "the template still answers for itself" do
    assert MediaGallery.name() == :media_gallery
    assert MediaGallery.label() == "Gallery"
    assert :select in MediaGallery.features()
    assert Keyword.get(MediaGallery.default_options(), :primary_action) == :edit
    assert Keyword.get(MediaGallery.default_options(), :overlay_action) == :toggle_featured
  end
end

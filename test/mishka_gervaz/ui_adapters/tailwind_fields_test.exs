defmodule MishkaGervaz.UIAdapters.TailwindFieldsTest do
  @moduledoc """
  Every field of the default adapter wears the same design, on and off.

  Two things had drifted. Half the inputs switched themselves off with `bg-gray-100` — Tailwind's
  COOL grey, next to this palette's warm neutrals — so a Category waiting on a Site read as a
  different kind of control rather than the same one, switched off. And four inputs kept a private
  copy of the FILTER look, so inside a form a number or a date sat at 42px on white beside a text
  field at 44px on `#faf9f6`.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias MishkaGervaz.UIAdapters.Tailwind

  defp render(fun, assigns) do
    %{__changed__: nil, name: "form[thing]", value: "", disabled: false, readonly: false}
    |> Map.merge(assigns)
    |> then(&apply(Tailwind, fun, [&1]))
    |> rendered_to_string()
  end

  @off [
    "text_input",
    "password_input",
    "date_input",
    "datetime_input",
    "number_input",
    "textarea"
  ]

  describe "the switched-off look" do
    test "is the same one for every field kind" do
      for fun <- @off do
        html = render(String.to_existing_atom(fun), %{disabled: true})

        assert html =~ Tailwind.disabled_class(), "#{fun} draws its own disabled state"
        refute html =~ "bg-gray-100", "#{fun} is still on the cool grey"
      end
    end

    test "readonly reads as disabled, because it is the same to a reader" do
      assert render(:text_input, %{readonly: true}) =~ Tailwind.disabled_class()
      assert render(:number_input, %{readonly: true}) =~ Tailwind.disabled_class()
    end

    test "an enabled field carries none of it" do
      refute render(:text_input, %{}) =~ "cursor-not-allowed"
      refute render(:number_input, %{}) =~ "cursor-not-allowed"
    end

    test "it is warm, and it is one string" do
      assert Tailwind.disabled_class() =~ "bg-[#f6f5f2]"
      refute Tailwind.disabled_class() =~ "gray"
    end
  end

  describe "the form look" do
    # A FORM FIELD SITS IN A FIELD CARD (44px, #faf9f6); a filter sits on the page (42px, white).
    # These four asked for neither — they hardcoded the filter one and wore it in both places.
    test "a field with no opinion gets the form variant" do
      for fun <- [:number_input, :date_input, :datetime_input, :password_input] do
        html = render(fun, %{})

        assert html =~ "h-11", "#{fun} is not the form height"
        assert html =~ "bg-[#faf9f6]", "#{fun} is not the form ground"
      end
    end

    test "a filter still asks for the filter variant" do
      html = render(:number_input, %{search: true})

      assert html =~ "h-[42px]"
      assert html =~ "bg-white"
    end

    test "a caller's own class still wins outright" do
      assert render(:number_input, %{class: "my-field"}) =~ ~s(class="my-field)
    end
  end

  # A RELATION FIELD SITS BESIDE THE OTHERS, so it has to be the same field. It used to pass the
  # form look as a literal — a workaround for an adapter that defaulted to the filter one — and the
  # literal had drifted: 12px of radius against 11, semibold against medium.
  describe "a relation field in a form" do
    test "is drawn by the adapter, not by a copy of the adapter" do
      assigns = %{
        __changed__: nil,
        name: :site_id,
        field: nil,
        options: [],
        placeholder: "Select site...",
        value: "",
        disabled: false
      }

      html = rendered_to_string(Tailwind.search_select(assigns))

      assert html =~ "rounded-[11px]"
      assert html =~ "h-11"
      assert html =~ "bg-[#faf9f6]"
      refute html =~ "rounded-[12px]"
    end

    test "and the type no longer carries one" do
      source = File.read!("lib/mishka_gervaz/form/types/field/relation.ex")

      refute source =~ "rounded-[12px]"
    end
  end

  # A DEPENDENT FIELD WAITING ON ITS PARENT is not drawn as an input at all — the standard template
  # puts a stand-in in its place, and that stand-in is the one the design report came in about:
  # `rounded` (4px) and `bg-gray-100`, beside a 44px `rounded-[11px]` field on `#faf9f6`. It needs
  # the adapter's own numbers, and it is asserted here rather than rendered because reaching it
  # needs a mounted component, a loaded form and a parent field with no value.
  #
  # TWO STAND-INS, because the field is waiting for two different things. Waiting for a CHOICE is
  # switched off and says so; waiting for OPTIONS is a control on its way and is drawn as a
  # skeleton, the same as every list in this admin.
  describe "the stand-in for a field that is waiting" do
    @template File.read!("lib/mishka_gervaz/form/templates/standard.ex")

    test "wears the field's shape either way" do
      shapes =
        Regex.scan(~r/flex h-11 w-full[a-z0-9\[\]#\- ]*rounded-\[11px\]/, @template)

      assert length(shapes) == 2, "both stand-ins are 44px and rounded-[11px]"
    end

    test "the one waiting on a choice keeps the switched-off colours" do
      assert @template =~ ~s(border-[#ecebe6] bg-[#f6f5f2])
      assert @template =~ ~s(text-[#8a877f])
      assert @template =~ "cursor-not-allowed"
    end

    test "the one waiting on its options is a skeleton on the field's own background" do
      assert @template =~ ~s(data-role="gervaz-field-skeleton")
      assert @template =~ ~s(border-[#f0efea] bg-[#faf9f6])
      assert @template =~ "animate-pulse"
    end

    test "and the skeleton still says what it is doing, for anything not looking at it" do
      assert @template =~ ~s(aria-busy="true")
      assert @template =~ ~s(<span class="sr-only">{@disabled_prompt}</span>)
    end

    test "and none of the old ones" do
      refute @template =~ "bg-gray-100 border-gray-200 text-gray-400"
      refute @template =~ "border-blue-200 text-blue-500"
    end
  end

  # THE FILE IN HAND, while it is still on its way. Rendering it needs a live upload, so the row is
  # asserted at the line that draws it — a `%Phoenix.LiveView.UploadEntry{}` cannot be conjured
  # without a socket that allowed the upload.
  describe "a staged upload" do
    test "is a card in this admin's colours, not the framework default" do
      assert @template =~ ~s(rounded-[12px] border border-[#ecebe6] bg-white p-[10px])
      refute @template =~ "bg-gray-50 rounded-lg border"
    end

    test "its progress bar is the accent, on the neutral track" do
      assert @template =~ ~s(rounded-full bg-[#5b57d6])
      assert @template =~ ~s(rounded-full bg-[#efeee9])
      refute @template =~ "bg-blue-600 h-1.5"
    end

    test "cancelling it is the same square as every other destructive action" do
      assert @template =~ ~s(hover:border-[#f3ddd9] hover:bg-[#fdf4f3] hover:text-[#c0392b])
      refute @template =~ "text-gray-400 hover:text-red-500 hover:bg-red-50"
    end
  end

  describe "the multi-line fields" do
    test "a textarea is the same field as the one above it, minus the fixed height" do
      html = render(:textarea, %{})

      assert html =~ "rounded-[11px]"
      assert html =~ "border-[#ecebe6]"
      assert html =~ "bg-[#faf9f6]"
      refute html =~ "rounded-md"
      refute html =~ "border-gray-300"
    end

    test "the JSON editor is that field in mono" do
      html = render(:json_editor, %{})

      assert html =~ "font-mono"
      assert html =~ "rounded-[11px]"
      refute html =~ "focus:ring-blue-500"
    end
  end
end

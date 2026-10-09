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
  # GROUPED AS `select/1`'s ARE: each group under its label, and a grouped option says which group it
  # came from once picked.
  describe "a search select with grouped options" do
    defp grouped_select(value) do
      %{
        __changed__: nil,
        name: :record,
        field: nil,
        options: [
          {"Nothing", "__nil__"},
          {"Blog", [{"Post", "blog:post"}, {"Tag", "blog:tag"}]},
          {"Docs", [{"Page", "docs:page"}]}
        ],
        value: value,
        disabled: false,
        dropdown_open?: true
      }
      |> Tailwind.search_select()
      |> rendered_to_string()
    end

    test "draws each group under its label, its options by their own label" do
      html = grouped_select("")

      assert html =~ ~r/uppercase[^"]*">\s*Blog\s*</
      assert html =~ ~r/uppercase[^"]*">\s*Docs\s*</
      assert html =~ ~r/phx-value-id="blog:post" phx-value-label="Blog · Post">\s*Post\s*</
    end

    test "a picked grouped option reads with its group, first, and not again in its group" do
      html = grouped_select("blog:post")

      assert html =~ ~s(name="_search_record" value="Blog · Post")
      assert html =~ ~r/phx-value-id="blog:post" phx-value-label="Blog · Post">\s*Blog · Post\s*</
      refute html =~ ~r/phx-value-id="blog:post" phx-value-label="Blog · Post">\s*Post\s*</
      assert html =~ ~r/phx-value-id="blog:tag" phx-value-label="Blog · Tag">\s*Tag\s*</
    end
  end

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

    # INLINE, A TEXTAREA SITS ON THE LINE'S BASELINE, and the line runs past its bottom edge: the
    # ring around a field with an error drew a second line under the box.
    test "are blocks, so the ring of a field with an error fits them" do
      for fun <- [:textarea, :json_editor] do
        assert render(fun, %{}) =~ ~r/class="block /, "#{fun}"
      end
    end
  end

  describe "the reading direction of a value" do
    test "an input whose value is always left to right says so" do
      for type <- ~w(email url tel) do
        assert render(:text_input, %{type: type}) =~ ~s(dir="ltr"), "#{type} follows the page"
      end

      assert render(:password_input, %{}) =~ ~s(dir="ltr")
      assert render(:number_input, %{}) =~ ~s(dir="ltr")
      assert render(:json_editor, %{}) =~ ~s(dir="ltr")
    end

    test "an input for free text follows what is typed" do
      assert render(:text_input, %{type: "text"}) =~ ~s(dir="auto")
      assert render(:textarea, %{}) =~ ~s(dir="auto")
    end

    test "a search input keeps the page's direction for its icon, and lets the text run its own" do
      html = render(:text_input, %{search: true})

      refute html =~ ~s(dir=)
      assert html =~ "[unicode-bidi:plaintext]"
    end

    test "a field can name its own direction" do
      assert render(:text_input, %{dir: "ltr"}) =~ ~s(dir="ltr")
      assert render(:textarea, %{dir: :ltr}) =~ ~s(dir="ltr")
    end

    test "a cell reads left to right when it holds a code or one ASCII token" do
      cell = fn fun, assigns ->
        %{__changed__: nil}
        |> Map.merge(assigns)
        |> then(&apply(Tailwind, fun, [&1]))
        |> rendered_to_string()
      end

      assert cell.(:cell_code, %{value: "f47ac10b..."}) =~ ~s(dir="ltr")
      assert cell.(:cell_text, %{text: "ali@example.com"}) =~ ~s(dir="ltr")
      refute cell.(:cell_text, %{text: "علی رضایی"}) =~ "dir="
      refute cell.(:cell_text, %{text: "Ali Reza"}) =~ "dir="
    end
  end

  describe "a multi-select in a form" do
    defp multi(assigns) do
      %{
        __changed__: nil,
        name: :region_ids,
        filter_name: :region_ids,
        table_id: "entry",
        options: [],
        selected: ["1", "2"],
        selected_options: [{"North", "1"}],
        myself: nil
      }
      |> Map.merge(assigns)
      |> Tailwind.multi_select()
      |> rendered_to_string()
    end

    test "shows what is picked while it is closed, each with a way to remove it" do
      html = multi(%{show_selected: true})

      assert html =~ ~s(data-role="gervaz-multi-selected")
      assert html =~ "North"
      assert html =~ ~s(aria-label="Remove North")

      assert html =~ ~s(aria-label="Remove 2"),
             "a value whose label is not known yet is shown as itself"

      assert html =~ ~s(phx-value-id="1")
    end

    test "and a table filter, which does not ask, shows none" do
      refute multi(%{}) =~ "gervaz-multi-selected"
    end
  end

  describe "a date and time" do
    test "a stored one is written as its input reads it" do
      for stored <- [~U[2024-09-09 22:45:00Z], ~N[2024-09-09 22:45:00]] do
        assert render(:datetime_input, %{value: stored}) =~ ~s(value="2024-09-09T22:45")
      end
    end

    test "one just typed is kept as it was typed" do
      assert render(:datetime_input, %{value: "2024-09-09T22:45"}) =~
               ~s(value="2024-09-09T22:45")
    end
  end

  describe "a form's calendar" do
    defp calendar(fun, value, month) do
      render(fun, %{
        id: "f_at",
        value: value,
        picker: %{month: month},
        field_name: :at,
        target: nil
      })
    end

    defp tag(html, pattern),
      do: Regex.run(~r/<[a-z]+[^>]*#{pattern}[^>]*>/s, html) |> List.first()

    test "closed, it is the value and a button that names it" do
      html = calendar(:datetime_input, ~U[2024-09-09 22:45:00Z], nil)

      assert tag(html, ~s(type="hidden")) =~ ~s(value="2024-09-09T22:45:00")
      assert tag(html, ~s(id="f_at")) =~ ~s(aria-expanded="false")
      assert html =~ "09 Sep 2024, 22:45"
      refute html =~ ~s(id="f_at-month")
    end

    test "with no value it asks for one" do
      html = calendar(:date_input, "", nil)

      assert tag(html, ~s(type="hidden")) =~ ~s(value="")
      assert html =~ "Pick a date"
    end

    test "open, it names the month and year shown and draws its days from Monday" do
      html = calendar(:datetime_input, ~N[2024-09-09 22:45:00], ~D[2024-09-01])

      assert tag(html, ~s(id="f_at")) =~ ~s(aria-expanded="true")
      assert html =~ ~r/id="f_at-month"[^>]*>\s*September 2024\s*</
      assert length(Regex.scan(~r/id="f_at-day-2024-09-\d\d"/, html)) == 30

      # 1 September 2024 is a Sunday: six empty cells come before it.
      [days] =
        Regex.run(~r/<div class="mt-1 grid grid-cols-7 gap-0.5">(.*?)<\/div>/s, html,
          capture: :all_but_first
        )

      assert days
             |> String.split("<button", parts: 2)
             |> hd()
             |> then(&Regex.scan(~r/<span><\/span>/, &1))
             |> length() == 6

      assert tag(html, ~s(id="f_at-day-2024-09-09")) =~ ~s(aria-pressed="true")
      assert tag(html, ~s(id="f_at-day-2024-09-10")) =~ ~s(aria-pressed="false")
      assert tag(html, ~s(id="f_at-hour")) =~ ~s(name="_gvz_picker[at][hour]")
      assert html =~ ~r/<option value="22" selected>/
      assert html =~ ~r/<option value="45" selected>/
    end

    test "a date has no time to pick" do
      html = calendar(:date_input, "2024-02-29", ~D[2024-02-01])

      assert html =~ ~r/id="f_at-month"[^>]*>\s*February 2024\s*</
      assert length(Regex.scan(~r/id="f_at-day-2024-02-\d\d"/, html)) == 29
      refute html =~ ~s(id="f_at-hour")
    end

    test "a filter, given no picker, keeps the browser's input" do
      assert render(:datetime_input, %{value: "2024-09-09T22:45"}) =~ ~s(type="datetime-local")
      assert render(:date_input, %{value: "2024-09-09"}) =~ ~s(type="date")
    end
  end

  describe "a list that opens under its control" do
    defp relation(fun, assigns) do
      %{
        __changed__: nil,
        name: :site_id,
        filter_name: :site_id,
        table_id: "entry",
        options: [{"North", "1"}],
        value: "",
        selected: [],
        placeholder: "Pick",
        disabled: false,
        myself: nil
      }
      |> Map.merge(assigns)
      |> then(&apply(Tailwind, fun, [&1]))
      |> rendered_to_string()
    end

    test "says on its control whether it is open" do
      for fun <- [:search_select, :multi_select, :load_more_select] do
        assert relation(fun, %{dropdown_open?: true}) =~ ~s(aria-expanded="true"), "#{fun}"
        assert relation(fun, %{dropdown_open?: false}) =~ ~s(aria-expanded="false"), "#{fun}"
      end
    end

    test "a switched-off search select is never open" do
      assert relation(:search_select, %{dropdown_open?: true, disabled: true}) =~
               ~s(aria-expanded="false")
    end

    test "a combobox opens and closes its list with the attribute" do
      html =
        relation(:combobox, %{field_name: :lang, target: nil, phx_debounce: 300, value: "en"})

      assert html =~ ~s(aria-controls="combobox-dropdown-entry-lang")
      assert html =~ ~s(aria-expanded="false")

      assert html =~ "[&quot;aria-expanded&quot;,&quot;true&quot;]"
      assert html =~ "[&quot;aria-expanded&quot;,&quot;false&quot;]"
    end
  end

  describe "a string list in a form" do
    defp list(items, disabled \\ false),
      do: render(:string_list_input, %{items: items, field_name: "origins", disabled: disabled})

    test "its add button stands in the 44px box, centred on an input beside it" do
      assert list([]) =~
               ~r/<div data-role="gervaz-list-add" class="flex h-11 items-center">\s*<button[^>]*phx-click="add_list_item"/
    end

    test "under the items it holds, and nowhere when the list is switched off" do
      assert list(["https://a.test"]) =~ ~s(data-role="gervaz-list-add")
      refute list(["https://a.test"], true) =~ ~s(data-role="gervaz-list-add")
    end
  end
end

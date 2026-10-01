defmodule MishkaGervaz.TranslatedDslTest do
  @moduledoc """
  Every string a resource's `mishka_gervaz` DSL holds reaches the page in the locale of the process
  that draws it, and in English, byte for byte, when no message translates it.

  `MishkaGervaz.Test.Resources.TranslatedDsl` declares each of them as a plain string marked with
  `dgettext_noop`. Each test below draws one in the locale `fa`, in which
  `MishkaGervaz.Test.Gettext` prefixes every string it translates with `"[fa:mishka_gervaz] "`, and
  in English, where it is the string itself. A locale the backend does not translate draws a string
  as written.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Form.Web.State, as: FormState
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Table.Templates.Table, as: TableTemplate

  alias MishkaGervaz.Table.Types.Action.{
    Destroy,
    Edit,
    Event,
    Link,
    PermanentDestroy,
    Unarchive,
    Update
  }

  alias MishkaGervaz.Table.Types.Column.{Avatars, Badge, Boolean, Tags}
  alias MishkaGervaz.Table.Types.Filter
  alias MishkaGervaz.Table.Web.State, as: TableState
  alias MishkaGervaz.Test.Resources.{ConstrainedMapForm, TranslatedDsl}
  alias MishkaGervaz.UIAdapters.Tailwind

  @backend MishkaGervaz.Test.Gettext
  @fa "[fa:mishka_gervaz] "
  @admin %{id: "user-1", role: :admin}
  @record %{id: "5d8431b3-1a65-482e-8bdb-962f6e35841b", title: "Cat"}

  defp locale(name), do: Gettext.put_locale(@backend, name)

  defp html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  # Whether `text` is in `html` anywhere the `fa` prefix is not in front of it.
  defp unprefixed?(html, text) do
    ~r/(?<!#{Regex.escape(@fa)})#{Regex.escape(text)}/ |> Regex.match?(html)
  end

  # What a string is drawn as in English and in Persian (`fa`): a pair, from one function.
  defp both(fun) do
    locale("en")
    english = fun.()
    locale("fa")
    {english, fun.()}
  end

  describe "a row action" do
    @ui Tailwind
    @target %Phoenix.LiveComponent.CID{cid: 1}

    defp row_action(module, action), do: html(module.render(%{}, action, @record, @ui, @target))

    test "a confirm string is translated and a confirm function is called" do
      for module <- [Destroy, Unarchive, Event, Edit, Update, PermanentDestroy] do
        action = %{ui: %{}, confirm: "Delete this draft?", name: :publish, event: "x", js: nil}

        {english, persian} = both(fn -> row_action(module, action) end)

        assert english =~ ~s(data-confirm="Delete this draft?"), inspect(module)
        assert persian =~ ~s(data-confirm="#{@fa}Delete this draft?"), inspect(module)

        function = %{action | confirm: fn record -> "Wipe #{record.title} for good?" end}

        {english, persian} = both(fn -> row_action(module, function) end)

        assert english =~ ~s(data-confirm="Wipe Cat for good?"), inspect(module)
        assert persian =~ ~s(data-confirm="Wipe Cat for good?"), inspect(module)
      end
    end

    test "a permanent_destroy with no confirm keeps its own message" do
      action = %{ui: %{}, confirm: nil, name: :wipe}

      assert row_action(PermanentDestroy, action) =~
               "Permanently delete this record? This cannot be undone."
    end

    test "a label string is translated, and so is the humanized name of an action with none" do
      for module <- [Event, Edit, Update, Link] do
        labelled = %{
          ui: %{label: "Heading"},
          confirm: nil,
          name: :other,
          event: "x",
          js: nil,
          path: "/x"
        }

        bare = %{ui: nil, confirm: nil, name: :publish, event: "x", js: nil, path: "/x"}

        {english, persian} = both(fn -> row_action(module, labelled) end)
        assert english =~ ~s(title="Heading"), inspect(module)
        assert persian =~ ~s(title="#{@fa}Heading"), inspect(module)

        {english, persian} = both(fn -> row_action(module, bare) end)
        assert english =~ ~s(title="Publish"), inspect(module)
        assert persian =~ ~s(title="#{@fa}Publish"), inspect(module)
      end
    end
  end

  describe "a bulk action" do
    defp bulk_button(action) do
      html(Tailwind.bulk_action_button(%{__changed__: nil, action: action, myself: nil}))
    end

    test "draws its label, its confirm and its humanized name in the caller's locale" do
      labelled = %{
        name: :archive_all,
        confirm: "Archive the selected posts?",
        ui: %{label: "Archive them", icon: nil, class: nil}
      }

      bare = %{name: :publish_all, confirm: nil, ui: nil}

      {english, persian} = both(fn -> bulk_button(labelled) end)
      assert english =~ ~s(data-confirm="Archive the selected posts?")
      assert english =~ "Archive them"
      assert persian =~ ~s(data-confirm="#{@fa}Archive the selected posts?")
      assert persian =~ "#{@fa}Archive them"

      {english, persian} = both(fn -> bulk_button(bare) end)
      assert english =~ "Publish all"
      assert persian =~ "#{@fa}Publish all"
      refute persian =~ "data-confirm"
    end

    test "calls a label function, and keeps a confirm of true or false" do
      ui = %{label: fn -> "From a function" end, icon: nil, class: nil}
      action = %{name: :go, confirm: true, ui: ui}

      assert bulk_button(action) =~ "From a function"
      refute bulk_button(%{action | confirm: false}) =~ "data-confirm"
    end
  end

  describe "a column type" do
    defp badge(value, extra) do
      html(Badge.render(value, %{ui: %{extra: extra}}, %{}, Tailwind))
    end

    test "a badge translates the label it declares for a value and the humanized value" do
      extra = %{labels: %{"published" => "Published"}}

      {english, persian} = both(fn -> badge("published", extra) end)
      assert english =~ "Published"
      assert persian =~ "#{@fa}Published"

      {english, persian} = both(fn -> badge(:archived, extra) end)
      assert english =~ "Archived"
      assert persian =~ "#{@fa}Archived"
    end

    test "a boolean translates the text it declares for each value" do
      column = %{ui: %{extra: %{true_label: "Featured", false_label: "Ordinary"}}}

      {english, persian} = both(fn -> html(Boolean.render(true, column, %{}, Tailwind)) end)
      assert english =~ "Featured"
      assert persian =~ "#{@fa}Featured"

      {english, persian} = both(fn -> html(Boolean.render(false, column, %{}, Tailwind)) end)
      assert english =~ "Ordinary"
      assert persian =~ "#{@fa}Ordinary"
    end

    test "tags and avatars translate the text they show when empty" do
      column = %{name: :tags, source: :tags, ui: %{extra: %{empty: "Nothing here yet"}}}

      {english, persian} = both(fn -> html(Tags.render(nil, column, %{tags: []}, Tailwind)) end)
      assert english =~ "Nothing here yet"
      assert persian =~ "#{@fa}Nothing here yet"

      {english, persian} =
        both(fn -> html(Avatars.render(nil, column, %{tags: []}, Tailwind)) end)

      assert english =~ "Nothing here yet"
      assert persian =~ "#{@fa}Nothing here yet"
    end
  end

  describe "a table filter" do
    defp filter(name) do
      state = TableState.init("filters", TranslatedDsl, @admin)
      Enum.find(state.static.filters, &(&1.name == name))
    end

    defp draw_filter(name, value \\ nil) do
      filter = filter(name)
      type = Filter.resolve_type(filter)
      html(type.render_input(filter, value, Tailwind))
    end

    test "a select translates its prompt and the labels of its options, never their values" do
      {english, persian} = both(fn -> draw_filter(:status) end)

      assert english =~ "Pick a status"
      assert english =~ ~s(<option value="draft">Draft</option>)
      assert english =~ ~s(<option value="published">Published</option>)

      assert persian =~ "#{@fa}Pick a status"
      assert persian =~ ~s(<option value="draft">#{@fa}Draft</option>)
      assert persian =~ ~s(<option value="published">#{@fa}Published</option>)
    end

    test "a text filter translates its placeholder, and a boolean filter its label" do
      {english, persian} = both(fn -> draw_filter(:search) end)
      assert english =~ ~s(placeholder="Search posts")
      assert persian =~ ~s(placeholder="#{@fa}Search posts")

      {english, persian} = both(fn -> draw_filter(:featured) end)
      assert english =~ "Featured only"
      assert persian =~ "#{@fa}Featured only"
    end
  end

  describe "the table" do
    defp table_state(updates \\ []) do
      "translated-dsl"
      |> TableState.init(TranslatedDsl, @admin)
      |> TableState.update(
        Keyword.merge(
          [loading: :loaded, has_initial_data?: true, page: 1, total_count: 25, total_pages: 3],
          updates
        )
      )
    end

    defp render_table(state, empty? \\ false) do
      stream_name = state.static.stream_name

      record = %{
        id: "row-1",
        title: "Cat",
        slug: "cat",
        status: :published,
        featured: true,
        inserted_at: nil
      }

      render_component(&TableTemplate.render/1, %{
        static: state.static,
        state: state,
        stream: (empty? && []) || [{"#{stream_name}-1", record}],
        streams: %{stream_name => []},
        empty?: empty?,
        myself: nil,
        __changed__: %{}
      })
    end

    test "draws its header, footer, notice, column labels and cells in the caller's locale" do
      {english, persian} = both(fn -> render_table(table_state()) end)

      for text <- [
            "All posts",
            "Everything that was ever written.",
            "Sorted by date.",
            "Heads up",
            "Drafts are hidden from visitors.",
            "Heading",
            "Slug",
            "Published",
            "Featured"
          ] do
        assert english =~ text, "English lost #{text}"
      end

      for text <- [
            "#{@fa}All posts",
            "#{@fa}Everything that was ever written.",
            "#{@fa}Sorted by date.",
            "#{@fa}Heads up",
            "#{@fa}Drafts are hidden from visitors.",
            "#{@fa}Heading",
            "#{@fa}Slug",
            "#{@fa}Published",
            "#{@fa}Featured"
          ] do
        assert persian =~ text, "Persian lost #{text}"
      end

      refute unprefixed?(persian, "Everything that was ever written.")
    end

    test "draws its filters, its row actions and its dropdown in the caller's locale" do
      {english, persian} = both(fn -> render_table(table_state()) end)

      assert english =~ "Pick a status"
      assert english =~ "Danger zone"
      assert english =~ ~s(data-confirm="Delete this draft?")
      assert english =~ ~s(data-confirm="Wipe Cat for good?")

      assert persian =~ "#{@fa}Pick a status"
      assert persian =~ "#{@fa}Danger zone"
      assert persian =~ ~s(data-confirm="#{@fa}Delete this draft?")
      assert persian =~ ~s(data-confirm="Wipe Cat for good?")
      assert persian =~ "#{@fa}Publish"
      assert persian =~ "#{@fa}Duplicate"
    end

    test "draws its bulk action bar in the caller's locale" do
      state = table_state(selected_ids: MapSet.new(["row-1"]))

      {english, persian} = both(fn -> render_table(state) end)

      assert english =~ "Archive all"
      assert english =~ "Publish all"
      assert english =~ ~s(data-confirm="Archive the selected posts?")
      assert persian =~ "#{@fa}Archive all"
      assert persian =~ "#{@fa}Publish all"
      assert persian =~ ~s(data-confirm="#{@fa}Archive the selected posts?")
    end

    test "draws its pagination in the caller's locale" do
      {english, persian} = both(fn -> render_table(table_state()) end)

      assert english =~ "Earlier"
      assert english =~ "Later"
      assert english =~ "Page 1 of 3"
      assert persian =~ "#{@fa}Earlier"
      assert persian =~ "#{@fa}Later"
      assert persian =~ "#{@fa}Page 1 of 3"
    end

    test "draws its empty state in the caller's locale" do
      state = table_state(total_count: 0)

      {english, persian} = both(fn -> render_table(state, true) end)

      assert english =~ "Nothing here yet"
      assert english =~ "Add one"
      assert persian =~ "#{@fa}Nothing here yet"
      assert persian =~ "#{@fa}Add one"
    end

    test "draws its error state in the caller's locale" do
      state = table_state()

      draw = fn ->
        render_component(&TableTemplate.render_error/1, %{
          static: state.static,
          state: state,
          myself: nil,
          __changed__: %{}
        })
      end

      {english, persian} = both(draw)

      assert english =~ "Could not load the posts"
      assert english =~ "Try again"
      assert persian =~ "#{@fa}Could not load the posts"
      assert persian =~ "#{@fa}Try again"
    end

    test "gives the English a resource wrote, byte for byte, when no message translates it" do
      state = table_state()

      static = %{
        state.static
        | pagination_ui: %{state.static.pagination_ui | next_label: "Onwards"}
      }

      locale("de")

      assert render_table(%{state | static: static}) =~ ~r/>\s*Onwards\s*</
    end
  end

  describe "the form" do
    defp form_state do
      "translated-dsl-form"
      |> FormState.init(TranslatedDsl, @admin)
      |> FormState.update(loading: :loaded, mode: :create, form: to_form(%{}, as: :form))
    end

    defp render_form(state \\ form_state()) do
      render_component(&Standard.render/1, %{
        static: state.static,
        state: state,
        ui: Tailwind,
        myself: nil,
        uploads: %{}
      })
    end

    test "draws its header, footer, notice, group, labels, placeholder and help in the caller's locale" do
      {english, persian} = both(fn -> render_form() end)

      for text <- [
            "Write a post",
            "Fill in the details below.",
            "Saved posts are published at once.",
            "Careful",
            "Changes are visible to everyone.",
            "Basic",
            "Post title",
            "Type a title",
            "Shown as the page heading.",
            "Status"
          ] do
        assert english =~ text, "English lost #{text}"
      end

      for text <- [
            "#{@fa}Write a post",
            "#{@fa}Fill in the details below.",
            "#{@fa}Saved posts are published at once.",
            "#{@fa}Careful",
            "#{@fa}Changes are visible to everyone.",
            "#{@fa}Basic",
            "#{@fa}Post title",
            "#{@fa}Type a title",
            "#{@fa}Shown as the page heading.",
            "#{@fa}Status"
          ] do
        assert persian =~ text, "Persian lost #{text}"
      end
    end

    test "draws a field with no label by its humanized name, translated" do
      {english, persian} = both(fn -> render_form() end)

      assert english =~ "Slug"
      refute english =~ "#{@fa}Slug"
      assert persian =~ "#{@fa}Slug"
      refute unprefixed?(persian, "Slug")
    end

    test "draws the labels of a select's options in the caller's locale, never their values" do
      {english, persian} = both(fn -> render_form() end)

      assert english =~ ~s(<option value="draft">Draft</option>)
      assert english =~ ~s(<option value="published">Published</option>)
      assert persian =~ ~s(<option value="draft">#{@fa}Draft</option>)
      assert persian =~ ~s(<option value="published">#{@fa}Published</option>)
    end

    test "draws the submit and cancel buttons it declared in the caller's locale" do
      state = %{form_state() | dirty?: true}

      {english, persian} = both(fn -> render_form(state) end)

      assert english =~ "Save the post"
      assert english =~ "Never mind"
      assert persian =~ "#{@fa}Save the post"
      assert persian =~ "#{@fa}Never mind"
    end

    test "draws the keys of a key map in the caller's locale" do
      base = FormInfo.field(ConstrainedMapForm, :settings)

      field = %{
        base
        | options: [
            [
              name: :theme,
              type: :select,
              label: "Item name",
              placeholder: "Pick a status",
              options: [{"Small", "s"}, {"Large", "l"}]
            ],
            [name: :note, type: :text, label: "Heading", placeholder: "Search posts"]
          ]
      }

      {english, persian} = both(fn -> render_field(field) end)

      assert english =~ "Item name"
      assert english =~ "Heading"
      assert english =~ ~s(placeholder="Search posts")
      assert english =~ ~s(<option value="">Pick a status</option>)
      assert english =~ ~s(<option value="s">Small</option>)

      assert persian =~ "#{@fa}Item name"
      assert persian =~ "#{@fa}Heading"
      assert persian =~ ~s(placeholder="#{@fa}Search posts")
      assert persian =~ ~s(<option value="">#{@fa}Pick a status</option>)
      assert persian =~ ~s(<option value="s">#{@fa}Small</option>)
      assert persian =~ ~s(<option value="l">#{@fa}Large</option>)
    end

    test "draws the buttons of a key list in the caller's locale" do
      base = FormInfo.field(ConstrainedMapForm, :links)
      field = %{base | ui: %{base.ui | add_label: "Add entry", remove_label: "Remove entry"}}
      form = ConstrainedMapForm |> AshPhoenix.Form.for_create(:create, forms: [auto?: false])
      form = form |> AshPhoenix.Form.validate(%{"links" => %{"0" => %{"platform" => "git"}}})

      {english, persian} = both(fn -> render_field(field, Phoenix.Component.to_form(form)) end)

      assert english =~ "Add entry"
      assert english =~ "Remove entry"
      assert persian =~ "#{@fa}Add entry"
      assert persian =~ "#{@fa}Remove entry"
    end

    defp render_field(field, form \\ to_form(%{}, as: :form)) do
      state =
        MishkaGervaz.Test.FormWebHelpers.build_state(
          static_opts: [fields: [field], groups: []],
          mode: :create,
          form: form
        )

      render_form(%{state | static: %{state.static | notices: []}})
    end

    test "draws the labels and options of a nested field in the caller's locale" do
      base = FormInfo.field(MishkaGervaz.Test.Resources.NestedForm, :tags)

      field =
        Map.update!(base, :nested_fields, fn [first | rest] ->
          [
            first
            |> Map.put(:label, "Item name")
            |> Map.put(:placeholder, "e.g. Widget")
            |> Map.put(:type, :select)
            |> Map.put(:options, [{"Small", "s"}, {"Large", "l"}])
            | rest
          ]
        end)
        |> Map.put(:add_label, "Add entry")

      {english, persian} = both(fn -> render_field(field) end)

      assert english =~ "Item name"
      assert english =~ ">Small</option>"
      assert english =~ "Add entry"
      assert persian =~ "#{@fa}Item name"
      assert persian =~ ">#{@fa}Small</option>"
      assert persian =~ ">#{@fa}Large</option>"
      assert persian =~ "#{@fa}Add entry"
      assert persian =~ ~s(value="s")
    end
  end
end

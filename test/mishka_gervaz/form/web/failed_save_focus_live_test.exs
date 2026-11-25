defmodule MishkaGervaz.Form.Web.FailedSaveFocusLiveTest do
  @moduledoc """
  What a refused save does to the page: the reader is moved to the first field with an error, and a
  page that mounts the form with `notify_failed` is told, so it can say so in a toast.

  The move is a hidden mark the form draws after each refusal, named after the count of refusals,
  whose `phx-mounted` is a `Phoenix.LiveView.JS` `focus_first` on the field's cell
  (`"<id>-field-<name>"`); focusing the field scrolls it into view. Driven on
  `MishkaGervaz.Test.Web.RulePageLive` (no groups) and the wizard of
  `MishkaGervaz.Test.Web.FormPageLive`.
  """
  use ExUnit.Case, async: false

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.FormPost
  alias MishkaGervaz.Test.Web.{RuleItem, WizardItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint

  setup do
    on_exit(fn ->
      for resource <- [RuleItem, WizardItem],
          do: resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  defp save(view, form, values) do
    view |> form(form, %{"form" => values}) |> render_submit()
    view
  end

  # Each mark the form drew for a refused save, as `{id, [{command, args}]}`.
  defp marks(view, form_id) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|span[id^="#{form_id}-failed-save-"]|)
    |> Enum.map(fn mark ->
      [id] = LazyHTML.attribute(mark, "id")
      [js] = LazyHTML.attribute(mark, "phx-mounted")
      {id, js |> Jason.decode!() |> Enum.map(fn [op, args] -> {op, args} end)}
    end)
  end

  describe "a refused save" do
    test "moves the reader to the first field with an error, in the order the form draws them" do
      view = save(open("/rules"), "#rule-form", %{"name" => "", "seats" => ""})

      assert [{"rule-failed-save-1", [{"focus_first", %{"to" => "#rule-field-name"}}]}] =
               marks(view, "rule")

      assert has_element?(view, ~s|#rule-field-name input[name="form[name]"]|)
      assert Ash.read!(RuleItem) == []
    end

    test "draws a new mark each time, so a second refusal moves the reader again" do
      view = open("/rules")
      save(view, "#rule-form", %{"name" => "", "seats" => "2"})
      save(view, "#rule-form", %{"name" => "Ann", "seats" => "11"})

      assert [{"rule-failed-save-2", [{"focus_first", %{"to" => "#rule-field-seats"}}]}] =
               marks(view, "rule")
    end

    test "moves nothing while the reader types, nor after a save that went through" do
      view = open("/rules")

      view |> form("#rule-form", %{"form" => %{"name" => ""}}) |> render_change()
      assert marks(view, "rule") == []

      save(view, "#rule-form", %{"name" => "Ann", "seats" => "2"})
      assert marks(view, "rule") == []
      assert has_element?(view, "#saved", "Ann")
    end

    test "on a wizard, moves to the field on the step the form went back to" do
      view = open("/wizard")
      save(view, "#wizard-form", %{"title" => "Hello", "address" => "refused.example"})
      save(view, "#wizard-form", %{"kind" => "post"})
      save(view, "#wizard-form", %{})

      assert [{_id, [{"focus_first", %{"to" => "#wizard-field-address"}}]}] =
               marks(view, "wizard")

      assert has_element?(view, ~s|[data-step="where"]:not([hidden]) #wizard-field-address|)
    end
  end

  describe "the page" do
    test "is told of each refused save with the fields that show an error" do
      view = open("/rules")
      save(view, "#rule-form", %{"name" => "", "seats" => ""})
      save(view, "#rule-form", %{"name" => "Ann", "seats" => "11"})

      lines =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(~s|[data-role="failed"]|)
        |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

      assert lines == ["create: name, seats", "create: seats"]
    end

    test "is told nothing by a save that went through" do
      view = open("/rules")
      save(view, "#rule-form", %{"name" => "Ann", "seats" => "2"})

      refute has_element?(view, ~s|[data-role="failed"]|)
    end
  end

  describe "a refusal no field shows" do
    test "moves the reader to the messages above the submit row" do
      state =
        build_state(
          static_opts: [fields: [FormInfo.field(FormPost, :title)], groups: []],
          mode: :create,
          form: to_form(%{}, as: :form)
        )

      static = %{state.static | notices: []}

      state = %{
        state
        | static: static,
          errors: %{},
          form_errors: ["This entry changed in another tab."],
          failed_saves: 1
      }

      html =
        render_component(&Standard.render/1, %{
          static: static,
          state: state,
          ui: MishkaGervaz.UIAdapters.Tailwind,
          myself: nil,
          uploads: %{}
        })

      doc = LazyHTML.from_fragment(html)

      assert [_alert] =
               doc
               |> LazyHTML.query(~s|##{static.id}-form-errors[tabindex="-1"]|)
               |> Enum.to_list()

      [js] =
        doc
        |> LazyHTML.query(~s|span[id="#{static.id}-failed-save-1"]|)
        |> LazyHTML.attribute("phx-mounted")

      assert [["focus", %{"to" => "#" <> rest}]] = Jason.decode!(js)
      assert rest == static.id <> "-form-errors"
    end
  end

  describe "a collapsed group holding the error" do
    test "is opened again by each refused save, even one the reader closed since" do
      field = FormInfo.field(FormPost, :title)

      opened_ids =
        for count <- [1, 2] do
          state =
            build_state(
              static_opts: [fields: [field], groups: []],
              mode: :create,
              form: to_form(%{}, as: :form)
            )

          state = %{state | errors: %{title: ["is required"]}, failed_saves: count}

          group = %{
            name: :more,
            fields: [:title],
            resolved_fields: [field],
            resolved_label: "More",
            collapsed: true,
            ui: %{class: nil, columns: nil, description: nil}
          }

          render_component(&Standard.render_group/1, %{
            group: group,
            static: state.static,
            state: state,
            myself: nil,
            uploads: %{}
          })
          |> LazyHTML.from_fragment()
          |> LazyHTML.query("span[phx-mounted][hidden]")
          |> LazyHTML.attribute("id")
        end

      assert [[first], [second]] = opened_ids
      assert first != second
    end
  end
end

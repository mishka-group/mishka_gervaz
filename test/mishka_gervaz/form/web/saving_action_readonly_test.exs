defmodule MishkaGervaz.Form.Web.SavingActionReadonlyTest do
  @moduledoc """
  A shown field the saving action does not take is drawn read-only and left out of the save.

  `MishkaGervaz.Test.Resources.SavingActionArticle` saves with `{:master_create, :create}` and
  `{:master_update, :update}`. A site user's `:create` takes no `:region_id`; a master's
  `:master_update` takes neither `:summary` nor `:region_id`. `:hint` is virtual and `:locked`
  declares `readonly true`.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Form.Web.{DataLoader, Events, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Form.Web.Events.SubmitHandler
  alias MishkaGervaz.Test.Resources.{PickerRegion, SavingActionArticle}

  @master %{id: "master-1", site_id: nil}
  @site_user %{id: "user-1", site_id: "0c8e5d0e-7c8c-4b8f-9d2a-4a4b1c1f0d11"}

  setup do
    for resource <- [SavingActionArticle, PickerRegion] do
      resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end

    region = Ash.create!(PickerRegion, %{name: "North"})

    article =
      Ash.create!(
        SavingActionArticle,
        %{title: "Old", summary: "Kept", region_id: region.id, locked: "L"},
        action: :master_create
      )

    %{region: region, article: article}
  end

  defp create_state(user) do
    state = State.init("article", SavingActionArticle, user)
    DataLoader.new_record(build_socket(state), state).assigns.form_state
  end

  defp update_socket(user, article) do
    state = "article" |> State.init(SavingActionArticle, user) |> State.update(mode: :update)
    {:ok, form} = RecordLoader.Default.load_for_edit(state, article.id, actor: user)
    DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, build_socket(state))
  end

  defp readonly_fields(state) do
    state.static.fields
    |> Enum.filter(&State.Helpers.field_readonly?(&1, state))
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  defp render_form(state) do
    render_component(&Standard.render/1, %{
      static: state.static,
      state: state,
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  defp input_tag(html, name) do
    [tag] = Regex.run(~r/<input(?=[^>]*name="#{Regex.escape(name)}")[^>]*>/, html)
    tag
  end

  describe "which fields are read-only" do
    test "a master creating: only the field that declares it", %{} do
      assert readonly_fields(create_state(@master)) == [:locked]
    end

    test "a site user creating: also the region their create does not take" do
      assert readonly_fields(create_state(@site_user)) == [:locked, :region_id]
    end

    test "a master editing: also the summary and the region their update does not take", ctx do
      state = update_socket(@master, ctx.article).assigns.form_state
      assert readonly_fields(state) == [:locked, :region_id, :summary]
    end

    test "a site user editing: the region, not the summary their update takes", ctx do
      state = update_socket(@site_user, ctx.article).assigns.form_state
      assert readonly_fields(state) == [:locked, :region_id]
    end

    test "a virtual field is never read-only for being outside the action" do
      state = create_state(@site_user)
      hint = Enum.find(state.static.fields, &(&1.name == :hint))

      assert State.Helpers.taken_by_action?(hint, state)
    end
  end

  describe "when the saving action cannot be found" do
    test "a form that is not an AshPhoenix form leaves every field as declared" do
      state = %{create_state(@site_user) | form: Phoenix.Component.to_form(%{}, as: :form)}
      assert readonly_fields(state) == [:locked]
    end

    test "an action the resource does not have leaves every field as declared" do
      state = create_state(@site_user)
      source = %{state.form.source | action: :no_such_action}
      state = %{state | form: %{state.form | source: source}}

      assert readonly_fields(state) == [:locked]
    end
  end

  describe "what a master editing sees and saves" do
    test "the summary and the region are drawn read-only, the title is not", ctx do
      html = update_socket(@master, ctx.article).assigns.form_state |> render_form()

      assert input_tag(html, "form[summary]") =~ "readonly"
      refute input_tag(html, "form[title]") =~ "readonly"
      assert input_tag(html, "_search_region_id") =~ "disabled"
      assert input_tag(html, "_search_region_id") =~ ~s(value="North")
    end

    test "a summary sent anyway is left out of what is saved", ctx do
      state = update_socket(@master, ctx.article).assigns.form_state

      assert SubmitHandler.drop_protected_fields(state, %{"title" => "New", "summary" => "X"}) ==
               %{"title" => "New"}
    end

    test "a refused save still shows the stored summary, not the one sent", ctx do
      {:noreply, socket} =
        Events.handle(
          "save",
          %{"form" => %{"title" => "", "summary" => "X"}},
          update_socket(@master, ctx.article)
        )

      refute_received {:form_saved, _mode, _record}

      html = render_form(socket.assigns.form_state)
      assert input_tag(html, "form[summary]") =~ ~s(value="Kept")
    end

    test "the title is saved and the stored summary kept", ctx do
      {:noreply, _socket} =
        Events.handle(
          "save",
          %{"form" => %{"title" => "New", "summary" => "X"}},
          update_socket(@master, ctx.article)
        )

      assert_received {:form_saved, :update, saved}
      assert {saved.title, saved.summary} == {"New", "Kept"}
    end

    test "a site user editing keeps the summary they may change", ctx do
      state = update_socket(@site_user, ctx.article).assigns.form_state

      assert SubmitHandler.drop_protected_fields(state, %{"title" => "New", "summary" => "X"}) ==
               %{"title" => "New", "summary" => "X"}
    end
  end
end

defmodule MishkaGervaz.Form.Web.StepFocusLiveTest do
  @moduledoc """
  Where the reader is put when a wizard or tabs form moves to another step: Next, Back or a tab
  draws a hidden mark, named after the count of moves, whose `phx-mounted` focuses the first field
  of the step moved to (`"<id>-step-<name>"`), so the focus never falls to the page. The form as
  it first opens draws no mark. Driven on the wizard of `MishkaGervaz.Test.Web.FormPageLive` and
  the free tabs of `MishkaGervaz.Test.Web.PlanPageLive`.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{PlanItem, WizardItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint

  setup do
    on_exit(fn ->
      for resource <- [PlanItem, WizardItem],
          do: resource |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    end)
  end

  defp open(path) do
    {:ok, view, _html} = live(build_conn(), path)
    render_async(view)
    view
  end

  # Each mark the form drew for a step move, as `{id, [{command, args}]}`.
  defp marks(view, form_id) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|span[id^="#{form_id}-step-moved-"]|)
    |> Enum.map(fn mark ->
      [id] = LazyHTML.attribute(mark, "id")
      [js] = LazyHTML.attribute(mark, "phx-mounted")
      {id, js |> Jason.decode!() |> Enum.map(fn [op, args] -> {op, args} end)}
    end)
  end

  describe "a wizard" do
    test "draws no mark as it opens" do
      assert marks(open("/wizard"), "wizard") == []
    end

    test "Next and Back each focus the first field of the step moved to" do
      view = open("/wizard")

      view
      |> form("#wizard-form", %{"form" => %{"title" => "Hello", "address" => "site.example"}})
      |> render_submit()

      assert [{"wizard-step-moved-1", [{"focus_first", %{"to" => "#wizard-step-what"}}]}] =
               marks(view, "wizard")

      view |> element(~s|#wizard-form [data-role="gervaz-step-back"]|) |> render_click()

      assert [{"wizard-step-moved-2", [{"focus_first", %{"to" => "#wizard-step-where"}}]}] =
               marks(view, "wizard")
    end

    test "Next that stays on a step with an error draws no new mark" do
      view = open("/wizard")

      view
      |> form("#wizard-form", %{"form" => %{"title" => "", "address" => "site.example"}})
      |> render_submit()

      assert marks(view, "wizard") == []
    end
  end

  describe "free tabs" do
    test "a tab focuses the first field of its panel" do
      view = open("/plans")
      assert marks(view, "plan") == []

      view |> element(~s|[role="tab"][data-step="pricing"]|) |> render_click()

      assert [{"plan-step-moved-1", [{"focus_first", %{"to" => "#plan-step-pricing"}}]}] =
               marks(view, "plan")
    end
  end
end

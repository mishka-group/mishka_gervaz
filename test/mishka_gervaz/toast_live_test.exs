defmodule MishkaGervaz.ToastLiveTest do
  @moduledoc """
  `MishkaGervaz.Toast`, driven the way a page uses it (`MishkaGervaz.Test.Web.ToastPageLive` on
  `/toasts`): a toast pushed from the page or sent from a component in it shows in the page's
  toasts, leaves by itself when its time is up, and leaves at once on its Close. Its Undo leaves it
  and hands the page what it stands for. A page keeps at most four.
  """
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @toast ~s|#gervaz-toasts [data-role="gervaz-toast"]|

  defp open do
    {:ok, view, _html} = live(build_conn(), "/toasts")
    view
  end

  defp press(view, id), do: view |> element("##{id}") |> render_click()

  # The page's process takes the messages in its mailbox in order: once it answers this call, every
  # message that reached it before, such as a toast's timer, has been handled, and its redraw sent
  # to the test's client.
  defp handled(view), do: :sys.get_state(view.pid)

  test "a pushed toast shows its sentence in its tone" do
    view = open()

    press(view, "saved")

    assert has_element?(view, ~s|#{@toast}[data-tone="ok"]|, "Saved.")
    assert has_element?(view, ~s|#gervaz-toasts[aria-live="polite"]|)
  end

  test "the toasts' container is the page's one live region, so a toast is read once" do
    view = open()

    press(view, "saved")
    doc = view |> render() |> LazyHTML.from_fragment()

    regions = LazyHTML.query(doc, "[aria-live], [role=status], [role=alert], [role=log]")
    assert regions |> LazyHTML.attribute("id") == ["gervaz-toasts"]
  end

  test "leaves by itself when its time is up" do
    view = open()
    :erlang.trace(view.pid, true, [:receive])

    press(view, "brief")
    assert_receive {:trace, _page, :receive, {:gervaz_toast_expire, _id}}
    handled(view)

    refute has_element?(view, @toast)
  end

  test "stays while its time runs" do
    view = open()

    press(view, "saved")
    handled(view)

    assert has_element?(view, @toast, "Saved.")
  end

  test "its Close takes it away" do
    view = open()
    press(view, "saved")

    view |> element(~s|#gervaz-toasts [data-role="gervaz-toast-close"]|) |> render_click()

    refute has_element?(view, @toast)
  end

  test "its Undo takes it away and hands the page what it stands for" do
    view = open()
    press(view, "deleted")

    assert has_element?(view, ~s|#{@toast}[data-tone="info"]|, "Item deleted.")

    view |> element(~s|#gervaz-toasts [data-role="gervaz-toast-undo"]|) |> render_click()

    refute has_element?(view, @toast)
    assert has_element?(view, "#undone", "item-42")
  end

  test "carries a link" do
    view = open()

    press(view, "exported")

    assert has_element?(
             view,
             ~s|#{@toast} [data-role="gervaz-toast-link"][href="/exports/1.csv"]|,
             "Download"
           )
  end

  test "a component in the page sends one" do
    view = open()

    view |> element("#from-component") |> render_click()

    assert has_element?(view, ~s|#{@toast}[data-tone="error"]|, "Could not save.")
  end

  defp shown(view), do: view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(@toast)

  test "keeps the four newest" do
    view = open()

    for _press <- 1..5, do: press(view, "counted")
    press(view, "deleted")

    assert Enum.count(shown(view)) == 4
    assert has_element?(view, @toast, "Item deleted.")
    assert has_element?(view, @toast, "Saved 5.")
    refute has_element?(view, @toast, "Saved 2.")
  end

  test "the same sentence again takes the place of the one shown, as the newest" do
    view = open()

    for _press <- 1..3, do: press(view, "saved")
    assert Enum.count(shown(view)) == 1

    press(view, "deleted")
    press(view, "saved")

    assert view |> shown() |> Enum.map(&(LazyHTML.text(&1) =~ "Saved.")) == [false, true]
  end

  test "the timer of the toast it took the place of does not take it away" do
    view = open()

    press(view, "saved")
    [first] = view |> shown() |> LazyHTML.attribute("id")
    press(view, "saved")
    [second] = view |> shown() |> LazyHTML.attribute("id")
    assert first != second

    "gervaz-toasts-" <> id = first
    send(view.pid, {:gervaz_toast_expire, String.to_integer(id)})
    handled(view)

    assert has_element?(view, "##{second}", "Saved.")
  end
end

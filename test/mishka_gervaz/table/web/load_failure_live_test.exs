defmodule MishkaGervaz.Table.Web.LoadFailureLiveTest do
  @moduledoc """
  A table whose first load fails, opened the way a reader opens it.

  The card stays: its filters are there to change, and where the rows go it shows the resource's
  `error_state`, its message and a Retry that loads the table again. The error goes to the log, never
  to the page: one line for a read that answers with one, and the exception of a load that raises.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.{GatedItem, LoadGate}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @filters "#items_gated_items-filter"
  @retry "button[phx-click=reload]"

  setup do
    start_supervised!(LoadGate)

    on_exit(fn -> GatedItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)

    Ash.create!(GatedItem, %{title: "A draft", status: "draft"})
    Ash.create!(GatedItem, %{title: "A published one", status: "published"})
    :ok
  end

  defp open_failing(path) do
    LoadGate.break()

    with_log(fn ->
      {:ok, view, _html} = live(build_conn(), path)
      render_async(view, @await)
      await_failed_loads()
      view
    end)
  end

  defp retry(view) do
    with_log(fn ->
      view |> element(@retry) |> render_click()
      render_async(view, @await)
      await_failed_loads()
    end)
  end

  defp await_failed_loads do
    for pid <- LoadGate.failed() do
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
    end
  end

  defp pick(view, status) do
    view
    |> element(@filters)
    |> render_change(%{"status" => status})
  end

  defp shown(view) do
    render_async(view, @await)

    shown = for item <- Ash.read!(GatedItem), row?(view, item), do: item.status
    Enum.sort(shown)
  end

  defp row?(view, item), do: has_element?(view, "#items_gated_items-#{item.id}")

  describe "a first load that fails" do
    test "keeps the filters and shows the error state where the rows go" do
      {view, _log} = open_failing("/items")

      assert has_element?(view, @filters)
      assert has_element?(view, @retry, "Retry")
      assert render(view) =~ "Error loading data"
      refute has_element?(view, "[data-role=gervaz-table-frame]")
    end

    test "logs the exception and keeps it off the page" do
      {view, log} = open_failing("/items")

      assert log =~ LoadGate.refused()
      refute render(view) =~ LoadGate.refused()
    end

    test "loads the table again on Retry" do
      {view, _log} = open_failing("/items")

      LoadGate.open()
      retry(view)

      assert shown(view) == ["draft", "published"]
      refute has_element?(view, @retry)
    end

    test "shows the error state again when Retry fails too" do
      {view, _log} = open_failing("/items")

      {_result, log} = retry(view)

      assert log =~ LoadGate.refused()
      assert has_element?(view, @filters)
      assert has_element?(view, @retry)
    end

    test "loads a filter picked after it" do
      {view, _log} = open_failing("/items")

      LoadGate.open()
      pick(view, "draft")

      assert shown(view) == ["draft"]
      assert_patch(view, "/items?filter_status=draft")
    end
  end

  describe "a read that answers with an error" do
    defp open_refused(path) do
      LoadGate.refuse()

      with_log(fn ->
        {:ok, view, _html} = live(build_conn(), path)
        render_async(view, @await)
        view
      end)
    end

    test "shows the error state and logs one line, with no crashed task" do
      {view, log} = open_refused("/items")

      assert has_element?(view, @filters)
      assert has_element?(view, @retry, "Retry")
      refute render(view) =~ LoadGate.refused()

      assert [line] = log |> String.split("\n") |> Enum.filter(&(&1 =~ LoadGate.refused()))
      assert line =~ "[warning]"
      assert line =~ "Failed to load page 1 of MishkaGervaz.Test.Web.GatedItem"
      refute log =~ "terminating"
    end

    test "loads the table again on Retry" do
      {view, _log} = open_refused("/items")

      LoadGate.open()
      retry(view)

      assert shown(view) == ["draft", "published"]
      refute has_element?(view, @retry)
    end

    test "of a filter picked later keeps the rows shown, and the next load shows its own" do
      {:ok, view, _html} = live(build_conn(), "/items")
      render_async(view, @await)
      LoadGate.refuse()

      {_result, log} =
        with_log(fn ->
          pick(view, "draft")
          render_async(view, @await)
        end)

      assert log =~ LoadGate.refused()
      refute log =~ "terminating"
      assert shown(view) == ["draft", "published"]

      LoadGate.open()
      pick(view, "published")
      assert shown(view) == ["published"]
    end
  end
end

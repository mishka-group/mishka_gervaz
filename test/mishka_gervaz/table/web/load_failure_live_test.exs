defmodule MishkaGervaz.Table.Web.LoadFailureLiveTest do
  @moduledoc """
  A table whose first load fails, opened the way a reader opens it.

  The card stays: its filters are there to change, and where the rows go it shows the resource's
  `error_state`, its message and a Retry that loads the table again. The exception goes to the log,
  never to the page.
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
end

defmodule MishkaGervaz.Form.Web.Events.DateRangeTest do
  @moduledoc """
  A `:date` or `:datetime` field's `min` and `max` bound the days its calendar offers and the
  values a save takes, and its `ui` `step` and `first_day_of_week` shape the calendar.

  `MishkaGervaz.Test.Resources.ScheduledEntry` may not publish in the past (`min` is a function
  read each time) and is due within ten fixed days. Each case drives the form's own events with
  what the rendered form posts, as a browser does, and checks the rendered form and the record.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 1]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Renderer, State}
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ScheduledEntry
  alias MishkaGervaz.UIAdapters.Tailwind

  @user %{id: "user-1", role: :admin}

  setup do
    ScheduledEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp create_form do
    state = State.init("scheduled-entry", ScheduledEntry, @user)
    DataLoader.new_record(build_socket(state), state)
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{
      form_state: socket.assigns.form_state,
      __changed__: %{}
    })
  end

  defp send_event(socket, event, params) do
    {:noreply, socket} = Events.handle(event, params, socket)
    socket
  end

  defp open_on(socket, field, %Date{} = month) do
    state = socket.assigns.form_state
    pickers = Map.put(state.pickers || %{}, field, month)
    Phoenix.Component.assign(socket, :form_state, State.update(state, pickers: pickers))
  end

  defp day_disabled?(html, field, %Date{} = day) do
    [button] =
      Regex.run(~r/<button[^>]*id="[^"]*#{field}-day-#{Date.to_iso8601(day)}"[^>]*>/, html)

    button =~ ~r/\sdisabled[\s>]/
  end

  defp shown(socket, field) do
    ~r/<input type="hidden" name="form\[#{field}\]" value="([^"]*)"/
    |> Regex.run(render_form(socket), capture: :all_but_first)
    |> List.first()
  end

  defp save(socket, params), do: send_event(socket, "save", %{"form" => params})

  describe "the DSL" do
    test "takes a min and a max as a value or a function, and the calendar's step and week" do
      publish_at = FormInfo.field(ScheduledEntry, :publish_at)
      due_on = FormInfo.field(ScheduledEntry, :due_on)

      assert is_function(publish_at.min, 0)
      assert publish_at.ui.step == 15
      assert publish_at.ui.first_day_of_week == :sunday
      assert {due_on.min, due_on.max} == {~D[2024-01-10], ~D[2024-01-20]}
    end
  end

  describe "the calendar" do
    test "greys out the days outside min and max" do
      html = create_form() |> open_on(:due_on, ~D[2024-01-01]) |> render_form()

      assert day_disabled?(html, :due_on, ~D[2024-01-09])
      refute day_disabled?(html, :due_on, ~D[2024-01-10])
      refute day_disabled?(html, :due_on, ~D[2024-01-20])
      assert day_disabled?(html, :due_on, ~D[2024-01-21])
    end

    test "reads a function min each time it draws, so past days are out and today is in" do
      today = Date.utc_today()
      month = Date.beginning_of_month(today)
      html = create_form() |> open_on(:publish_at, month) |> render_form()

      refute day_disabled?(html, :publish_at, today)
      if today != month, do: assert(day_disabled?(html, :publish_at, Date.add(today, -1)))

      test_pid = self()
      socket = open_on(create_form(), :publish_at, ~D[2024-01-01])
      state = socket.assigns.form_state

      fields =
        Enum.map(state.static.fields, fn
          %{name: :publish_at} = field ->
            %{
              field
              | min: fn ->
                  send(test_pid, :min_read)
                  ~U[2024-01-15 08:00:00Z]
                end
            }

          field ->
            field
        end)

      state = %{state | static: %{state.static | fields: fields}}
      html = socket |> Phoenix.Component.assign(:form_state, state) |> render_form()

      assert_received :min_read
      assert day_disabled?(html, :publish_at, ~D[2024-01-14])
      refute day_disabled?(html, :publish_at, ~D[2024-01-15])
    end

    test "starts its weeks on first_day_of_week and offers the minutes step apart" do
      html = create_form() |> open_on(:publish_at, Date.utc_today()) |> render_form()

      assert [first | _] = Regex.scan(~r/<span>(\w\w)<\/span>/, html, capture: :all_but_first)
      assert first == ["Su"]

      [minutes] =
        Regex.run(~r/<select[^>]*name="_gvz_picker\[publish_at\]\[minute\]".*?<\/select>/s, html)

      assert ~r/value="(\d+)"/ |> Regex.scan(minutes, capture: :all_but_first) |> List.flatten() ==
               ["0", "15", "30", "45"]
    end

    test "the browser's own input carries min, max and the step in seconds" do
      html =
        render_component(&Tailwind.datetime_input/1, %{
          name: "at",
          value: nil,
          min: "2024-01-10T08:00:00",
          max: "2024-01-20T23:59:59",
          step: 15
        })

      assert html =~ ~s(min="2024-01-10T08:00:00")
      assert html =~ ~s(max="2024-01-20T23:59:59")
      assert html =~ ~s(step="900")
    end
  end

  describe "picking" do
    test "a day outside the range is moved to its edge" do
      socket = create_form()

      early = send_event(socket, "picker_day", %{"field" => "due_on", "date" => "2024-01-02"})
      assert shown(early, :due_on) == "2024-01-10"

      late = send_event(socket, "picker_day", %{"field" => "due_on", "date" => "2024-02-02"})
      assert shown(late, :due_on) == "2024-01-20"
    end

    test "today at a past time is moved to now" do
      socket = create_form()
      today = Date.to_iso8601(Date.utc_today())
      picked = send_event(socket, "picker_day", %{"field" => "publish_at", "date" => today})

      {:ok, at} = NaiveDateTime.from_iso8601(shown(picked, :publish_at))
      refute NaiveDateTime.before?(at, NaiveDateTime.add(NaiveDateTime.utc_now(), -60))
    end

    test "a change posted before the pick was drawn keeps the pick, and the save stores it" do
      socket =
        create_form()
        |> send_event("picker_day", %{"field" => "due_on", "date" => "2024-01-12"})
        |> send_event("picker_close", %{"field" => "due_on"})
        |> send_event("validate", %{
          "_target" => ["form", "title"],
          "form" => %{"title" => "Typed", "due_on" => ""}
        })

      assert shown(socket, :due_on) == "2024-01-12"

      save(socket, %{"title" => "Typed", "due_on" => ""})
      assert [%{due_on: ~D[2024-01-12]}] = Ash.read!(ScheduledEntry)
    end
  end

  describe "saving" do
    test "refuses a day after max and a time before min, with the field's error" do
      late = save(create_form(), %{"title" => "Late", "due_on" => "2024-01-25"})
      assert Map.has_key?(late.assigns.form_state.errors, :due_on)

      past = save(create_form(), %{"title" => "Past", "publish_at" => "2020-01-01T10:00"})
      assert Map.has_key?(past.assigns.form_state.errors, :publish_at)

      assert Ash.read!(ScheduledEntry) == []
    end

    test "takes values within the range" do
      next_year = Date.utc_today().year + 1

      save(create_form(), %{
        "title" => "Within",
        "due_on" => "2024-01-15",
        "publish_at" => "#{next_year}-03-01T09:30"
      })

      assert [%{due_on: ~D[2024-01-15], publish_at: %DateTime{year: ^next_year}}] =
               Ash.read!(ScheduledEntry)
    end
  end
end

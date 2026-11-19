defmodule MishkaGervaz.Form.Web.MultiSelectSubmitTest do
  @moduledoc """
  A `:multi_select` field with static options draws one named checkbox per option, under
  `form[name][]`, and a save sends the ticked values as a list: an `{:array, :string}` or
  `{:array, :atom}` attribute and an `{:array, :string}` argument all save what was ticked, and
  ticking none saves an empty list.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Live, Renderer, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Test.Resources.WebhookEntry

  @user %{id: "user-1", site_id: nil}

  setup do
    WebhookEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp creating do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(%{id: "webhook-entry", resource: WebhookEntry, current_user: @user}, socket)

    socket
  end

  defp editing(entry) do
    state = "webhook-entry" |> State.init(WebhookEntry, @user) |> State.update(mode: :update)
    {:ok, form} = RecordLoader.Default.load_for_edit(state, entry.id, actor: @user)

    DataLoader.Default.handle_async_result(
      :load_record,
      {:ok, {:ok, form}},
      build_socket(state, assigns: %{record_id: entry.id})
    )
  end

  defp save(socket, params) do
    {:noreply, socket} = Events.handle("save", %{"form" => params}, socket)
    socket
  end

  defp validate(socket, params) do
    {:noreply, socket} = Events.handle("validate", %{"form" => params}, socket)
    socket
  end

  defp inputs(socket, name) do
    html = render_component(&Renderer.render/1, %{form_state: socket.assigns.form_state})

    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s(input[name="form[#{name}][]"]))
    |> Enum.map(fn input ->
      %{
        type: input |> LazyHTML.attribute("type") |> List.first(),
        value: input |> LazyHTML.attribute("value") |> List.first(),
        checked?: LazyHTML.attribute(input, "checked") != []
      }
    end)
  end

  defp ticked(socket, name) do
    for %{type: "checkbox", checked?: true, value: value} <- inputs(socket, name), do: value
  end

  describe "drawing" do
    test "one named checkbox per option, after an empty value that stands for none" do
      inputs = inputs(creating(), "event_types")

      assert [%{type: "hidden", value: ""} | boxes] = inputs
      assert Enum.map(boxes, & &1.type) == ["checkbox", "checkbox", "checkbox"]
      assert Enum.map(boxes, & &1.value) == ["order.paid", "order.refunded", "dispute.opened"]
      refute Enum.any?(boxes, & &1.checked?)
    end

    test "an update form ticks the saved values" do
      entry =
        Ash.create!(WebhookEntry, %{
          title: "Hook",
          event_types: ["order.refunded"],
          kinds: [:payout]
        })

      socket = editing(entry)

      assert ticked(socket, "event_types") == ["order.refunded"]
      assert ticked(socket, "kinds") == ["payout"]
    end

    test "a validate keeps what was ticked" do
      socket = creating() |> validate(%{"event_types" => ["", "order.paid", "dispute.opened"]})

      assert ticked(socket, "event_types") == ["order.paid", "dispute.opened"]
    end
  end

  describe "saving" do
    test "two of three are saved as a list" do
      creating()
      |> save(%{
        "title" => "Hook",
        "event_types" => ["", "order.paid", "dispute.opened"],
        "kinds" => ["", "refund", "dispute"],
        "channels" => ["", "email", "sms"]
      })

      assert [saved] = Ash.read!(WebhookEntry)
      assert saved.event_types == ["order.paid", "dispute.opened"]
      assert saved.kinds == [:refund, :dispute]
      assert saved.channels_saved == ["email", "sms"]
    end

    test "then none saves an empty list" do
      entry =
        Ash.create!(WebhookEntry, %{
          title: "Hook",
          event_types: ["order.paid", "dispute.opened"],
          kinds: [:refund]
        })

      entry
      |> editing()
      |> save(%{
        "title" => "Hook",
        "event_types" => [""],
        "kinds" => [""],
        "channels" => [""]
      })

      saved = Ash.get!(WebhookEntry, entry.id)
      assert saved.event_types == []
      assert saved.kinds == []
      assert saved.channels_saved == []
    end
  end
end

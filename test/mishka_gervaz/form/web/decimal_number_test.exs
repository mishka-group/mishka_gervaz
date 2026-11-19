defmodule MishkaGervaz.Form.Web.DecimalNumberTest do
  @moduledoc """
  A `:number` field for a `Decimal` attribute or argument draws its value, on an update form and
  again after a failed save, and saves what was typed as a `Decimal`.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import MishkaGervaz.Test.FormWebHelpers, only: [build_socket: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{DataLoader, Events, Live, Renderer, State}
  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader
  alias MishkaGervaz.Test.Resources.PricedEntry

  @user %{id: "user-1", site_id: nil}

  setup do
    PricedEntry |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp creating do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(%{id: "priced-entry", resource: PricedEntry, current_user: @user}, socket)

    socket
  end

  defp editing(entry) do
    state = "priced-entry" |> State.init(PricedEntry, @user) |> State.update(mode: :update)
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

  defp input_value(socket, name) do
    html = render_component(&Renderer.render/1, %{form_state: socket.assigns.form_state})

    [_, value] =
      Regex.run(~r/<input[^>]*name="form\[#{name}\]"[^>]*value="([^"]*)"/, html) ||
        [nil, nil]

    value
  end

  defp entry!(attrs) do
    PricedEntry
    |> Ash.Changeset.for_create(:create, Map.merge(%{title: "Lamp"}, attrs))
    |> Ash.create!()
  end

  describe "an update form" do
    test "draws the saved Decimal" do
      socket = editing(entry!(%{amount: Decimal.new("12.50")}))

      assert input_value(socket, "amount") == "12.50"
    end

    test "draws it again after a failed save that left it alone" do
      socket = entry!(%{amount: Decimal.new("12.50")}) |> editing() |> save(%{"title" => ""})

      assert socket.assigns.form_state.errors[:title] != nil
      assert input_value(socket, "amount") == "12.50"
    end

    test "draws what was typed after a failed save" do
      socket =
        entry!(%{amount: Decimal.new("12.50")})
        |> editing()
        |> save(%{"title" => "", "amount" => "13.75", "fee" => "1.5"})

      assert input_value(socket, "amount") == "13.75"
      assert input_value(socket, "fee") == "1.5"
    end

    test "saves a new amount as a Decimal" do
      entry = entry!(%{amount: Decimal.new("12.50")})
      entry |> editing() |> save(%{"title" => "Lamp", "amount" => "14.20", "fee" => "0.75"})

      saved = Ash.get!(PricedEntry, entry.id)
      assert Decimal.equal?(saved.amount, Decimal.new("14.20"))
      assert Decimal.equal?(saved.fee_paid, Decimal.new("0.75"))
    end
  end

  describe "a create form" do
    test "saves the amount and the fee as Decimals" do
      creating() |> save(%{"title" => "Lamp", "amount" => "19.99", "fee" => "2.5"})

      assert [saved] = Ash.read!(PricedEntry)
      assert Decimal.equal?(saved.amount, Decimal.new("19.99"))
      assert Decimal.equal?(saved.fee_paid, Decimal.new("2.5"))
    end

    test "draws what was typed after a failed save" do
      socket = creating() |> save(%{"title" => "", "amount" => "19.99", "fee" => "2.5"})

      assert Ash.read!(PricedEntry) == []
      assert input_value(socket, "amount") == "19.99"
      assert input_value(socket, "fee") == "2.5"
    end
  end
end

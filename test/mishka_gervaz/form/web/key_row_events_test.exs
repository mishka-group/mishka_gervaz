defmodule MishkaGervaz.Form.Web.KeyRowEventsTest do
  @moduledoc """
  Adding and removing one row of a `:key_list` sub-field.

  `add_nested` and `remove_nested` reach the rows of a constrained-map field. A `:key_list` lives
  one level further in — `params[field][index][sub]` — and nothing reached there, which is the whole
  reason a list like a slot's `attrs` could only ever be edited as a JSON textarea.

  Every part of that address arrives from the client on `phx-value-*`, so the guards are as much the
  feature as the writing is: a crafted event must not be able to put an arbitrary key into a
  constrained map.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers

  alias MishkaGervaz.Form.Web.Events
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ConstrainedMapForm

  defp key_list_field do
    ConstrainedMapForm
    |> FormInfo.field(:slots)
    |> Map.update!(:nested_fields, fn [first | rest] ->
      [
        first
        |> Map.put(:name, :attrs)
        |> Map.put(:type, :key_list)
        |> Map.put(:options, [[name: :name, type: :text], [name: :required, type: :toggle]])
        | rest
      ]
    end)
  end

  defp socket_with(rows) do
    form =
      ConstrainedMapForm
      |> AshPhoenix.Form.for_create(:create, forms: [auto?: false])
      |> AshPhoenix.Form.validate(%{
        "title" => "t",
        "slots" => %{"0" => %{"name" => "inner_block", "attrs" => rows}}
      })
      |> Phoenix.Component.to_form()

    [fields: [key_list_field()], groups: []]
    |> then(&build_state(static_opts: &1, mode: :create, form: form))
    |> build_socket()
  end

  defp attrs_of(socket) do
    socket.assigns.form_state.form.source
    |> AshPhoenix.Form.params()
    |> get_in(["slots", "0", "attrs"])
  end

  defp add(socket, params), do: Events.handle("add_key_row", params, socket)
  defp remove(socket, params), do: Events.handle("remove_key_row", params, socket)

  @address %{"field" => "slots", "index" => "0", "sub" => "attrs"}

  describe "add_key_row" do
    test "appends an empty row to the list inside that row" do
      {:noreply, socket} = add(socket_with(%{}), @address)

      assert attrs_of(socket) == %{"0" => %{}}
    end

    test "and keeps the rows already there, in order" do
      rows = %{"0" => %{"name" => "label"}, "1" => %{"name" => "hint"}}

      {:noreply, socket} = add(socket_with(rows), @address)

      assert %{"0" => %{"name" => "label"}, "1" => %{"name" => "hint"}, "2" => %{}} =
               attrs_of(socket)
    end
  end

  describe "remove_key_row" do
    test "takes one row out and closes the gap" do
      rows = %{"0" => %{"name" => "label"}, "1" => %{"name" => "hint"}}

      {:noreply, socket} = remove(socket_with(rows), Map.put(@address, "row", "0"))

      assert attrs_of(socket) == %{"0" => %{"name" => "hint"}}
    end

    # The last row has to be removable. An empty map says "this list is empty now"; leaving the key
    # out instead would read as "unchanged" everywhere downstream.
    test "including the last one" do
      {:noreply, socket} =
        remove(socket_with(%{"0" => %{"name" => "label"}}), Map.put(@address, "row", "0"))

      assert attrs_of(socket) == %{}
    end

    test "and a row that is not there changes nothing" do
      rows = %{"0" => %{"name" => "label"}}

      {:noreply, socket} = remove(socket_with(rows), Map.put(@address, "row", "7"))

      assert attrs_of(socket) == %{"0" => %{"name" => "label"}}
    end
  end

  # Every part of the address came from the client. None of these may write anything, and none may
  # crash the form either — a refused event is a no-op, not an error page.
  describe "an address the declaration does not agree with" do
    test "a field this form does not declare" do
      {:noreply, socket} = add(socket_with(%{}), %{@address | "field" => "secrets"})

      assert attrs_of(socket) == %{}
    end

    test "a sub-field that is not a key list on it" do
      {:noreply, socket} = add(socket_with(%{}), %{@address | "sub" => "name"})

      assert attrs_of(socket) == %{}
    end

    test "a row index that is not a whole number" do
      for index <- ["-1", "1e3", "zero", "0.5"] do
        {:noreply, socket} = add(socket_with(%{}), %{@address | "index" => index})

        assert attrs_of(socket) == %{}, "index #{index} must write nothing"
      end
    end

    test "a row index past the end" do
      {:noreply, socket} = add(socket_with(%{}), %{@address | "index" => "9"})

      assert attrs_of(socket) == %{}
    end

    test "and a form that is not there at all" do
      socket = build_socket(build_state(static_opts: [fields: [key_list_field()], groups: []]))

      assert {:noreply, _socket} = add(socket, @address)
      assert {:noreply, _socket} = remove(socket, Map.put(@address, "row", "0"))
    end
  end
end

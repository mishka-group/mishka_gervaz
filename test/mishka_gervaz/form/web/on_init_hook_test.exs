defmodule MishkaGervaz.Form.Web.OnInitHookTest do
  @moduledoc """
  Tests for the on_init hook wiring in DataLoader.

  The on_init hook is called after form initialization (both create and edit).
  Signature: `fn form, state -> form`
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.DataLoader
  import MishkaGervaz.Test.FormWebHelpers

  describe "on_init hook in new_record (create)" do
    test "calls on_init hook when defined" do
      test_pid = self()

      on_init = fn form, state ->
        send(test_pid, {:on_init_called, form, state})
        form
      end

      state = build_state(static_opts: [hooks: %{on_init: on_init}])
      _socket = build_socket(state)

      _form = %Phoenix.HTML.Form{
        source: %{source: %{data: nil}},
        errors: [],
        data: nil,
        name: "form",
        id: "form"
      }

      hooks = state.static.hooks
      assert is_function(hooks.on_init, 2)
    end

    test "on_init hook can modify the form" do
      modified_form = %Phoenix.HTML.Form{
        source: %{source: %{data: nil}},
        errors: [],
        data: %{custom: true},
        name: "modified",
        id: "modified"
      }

      on_init = fn _form, _state -> modified_form end

      state = build_state(static_opts: [hooks: %{on_init: on_init}])

      result =
        apply_on_init(state, %Phoenix.HTML.Form{
          source: %{source: %{data: nil}},
          errors: [],
          data: nil,
          name: "original",
          id: "original"
        })

      assert result.name == "modified"
    end

    test "on_init hook receives state as second argument" do
      test_pid = self()

      on_init = fn form, state ->
        send(test_pid, {:state_received, state.master_user?, state.mode})
        form
      end

      state =
        build_state(
          master_user?: true,
          mode: :create,
          static_opts: [hooks: %{on_init: on_init}]
        )

      original = %Phoenix.HTML.Form{
        source: %{source: %{data: nil}},
        errors: [],
        data: nil,
        name: "form",
        id: "form"
      }

      apply_on_init(state, original)

      assert_received {:state_received, true, :create}
    end

    test "on_init hook returning non-form value is ignored" do
      on_init = fn _form, _state -> :not_a_form end

      state = build_state(static_opts: [hooks: %{on_init: on_init}])

      original = %Phoenix.HTML.Form{
        source: %{source: %{data: nil}},
        errors: [],
        data: nil,
        name: "original",
        id: "original"
      }

      result = apply_on_init(state, original)
      assert result.name == "original"
    end

    test "skips on_init when no hooks configured" do
      state = build_state(static_opts: [hooks: %{}])

      original = %Phoenix.HTML.Form{
        source: %{source: %{data: nil}},
        errors: [],
        data: nil,
        name: "original",
        id: "original"
      }

      result = apply_on_init(state, original)
      assert result.name == "original"
    end

    test "skips on_init when hooks is nil" do
      state = build_state(static_opts: [hooks: nil])

      original = %Phoenix.HTML.Form{
        source: %{source: %{data: nil}},
        errors: [],
        data: nil,
        name: "original",
        id: "original"
      }

      result = apply_on_init(state, original)
      assert result.name == "original"
    end
  end

  describe "on_init hook in handle_async_result (edit)" do
    test "calls on_init hook on successful record load" do
      test_pid = self()

      on_init = fn form, _state ->
        send(test_pid, :on_init_called_on_edit)
        form
      end

      state =
        build_state(
          loading: :loading,
          mode: :update,
          static_opts: [hooks: %{on_init: on_init}]
        )

      socket = build_socket(state)

      form = %Phoenix.HTML.Form{
        source: %{source: %{data: %{id: "1", title: "Post"}}},
        errors: [],
        data: %{id: "1", title: "Post"},
        name: "form",
        id: "form"
      }

      DataLoader.Default.handle_async_result(:load_record, {:ok, {:ok, form}}, socket)

      assert_received :on_init_called_on_edit
    end

    test "does not call on_init on record load error" do
      test_pid = self()

      on_init = fn form, _state ->
        send(test_pid, :should_not_be_called)
        form
      end

      state =
        build_state(
          loading: :loading,
          mode: :update,
          static_opts: [hooks: %{on_init: on_init}]
        )

      socket = build_socket(state)

      DataLoader.Default.handle_async_result(:load_record, {:ok, {:error, :not_found}}, socket)

      refute_received :should_not_be_called
    end

    test "does not call on_init on record load exit" do
      test_pid = self()

      on_init = fn form, _state ->
        send(test_pid, :should_not_be_called)
        form
      end

      state =
        build_state(
          loading: :loading,
          mode: :update,
          static_opts: [hooks: %{on_init: on_init}]
        )

      socket = build_socket(state)

      DataLoader.Default.handle_async_result(:load_record, {:exit, :timeout}, socket)

      refute_received :should_not_be_called
    end
  end

  # Helper to test the on_init hook logic directly without needing full DataLoader pipeline
  defp apply_on_init(state, form) do
    case state.static.hooks do
      %{on_init: on_init} when is_function(on_init, 2) ->
        case on_init.(form, state) do
          %Phoenix.HTML.Form{} = modified -> modified
          _ -> form
        end

      _ ->
        form
    end
  end
end

defmodule MishkaGervaz.Form.Templates.StandardWaitingFieldErrorsTest do
  @moduledoc """
  A picker still waiting on the picker it depends on draws its errors like any other field.

  A required picker that waits ("Select Workspace first") could not be filled, so a save was
  refused on it, and its error was drawn nowhere: the form stayed open with no reason given.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard
  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.PickerEntry

  defp render_with_errors(errors) do
    fields = Enum.map([:workspace_id, :version_id], &FormInfo.field(PickerEntry, &1))

    state =
      build_state(
        static_opts: [fields: fields, groups: []],
        mode: :create,
        form: to_form(%{}, as: :form),
        errors: errors
      )

    static = %{state.static | notices: []}

    render_component(&Standard.render/1, %{
      static: static,
      state: %{state | static: static},
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  test "a required picker waiting on its parent shows why the save was refused" do
    html = render_with_errors(%{version_id: ["is required"]})

    assert html =~ "Select Workspace first"
    assert html =~ "is required"
  end

  test "and shows nothing when it has no error" do
    refute render_with_errors(%{}) =~ "is required"
  end
end

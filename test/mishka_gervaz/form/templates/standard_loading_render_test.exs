defmodule MishkaGervaz.Form.Templates.StandardLoadingRenderTest do
  @moduledoc """
  While its record loads, the form says so in words beside the spinner, and keeps a height of its
  own so the card around it does not collapse and jump when the fields arrive.
  """
  use ExUnit.Case, async: true

  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Templates.Standard

  @backend MishkaGervaz.Test.Gettext

  defp render_form(loading) do
    state = build_state(mode: :update, loading: loading, form: nil)
    static = %{state.static | notices: []}
    state = %{state | static: static}

    render_component(&Standard.render/1, %{
      static: static,
      state: state,
      ui: MishkaGervaz.UIAdapters.Tailwind,
      myself: nil,
      uploads: %{}
    })
  end

  defp loading_box(html) do
    [_, box] = Regex.run(~r/(<div data-role="gervaz-form-loading".*?<\/p>\s*<\/div>)/s, html)
    box
  end

  for loading <- [:initial, :loading] do
    test "#{loading}: shows the spinner over a Loading… label" do
      box = render_form(unquote(loading)) |> loading_box()

      assert box =~ "animate-spin"

      assert box =~
               ~r/<p class="mt-2 text-\[12.5px\] font-medium text-\[#8a877f\]">\s*Loading…\s*<\/p>/
    end
  end

  test "keeps a minimum height and announces itself as a status" do
    box = render_form(:loading) |> loading_box()

    assert box =~ "min-h-[280px]"
    assert box =~ ~s(role="status")
  end

  test "is gone once the record is loaded" do
    html =
      build_state(mode: :create, form: Phoenix.Component.to_form(%{}, as: :form))
      |> then(fn state ->
        static = %{state.static | notices: []}

        render_component(&Standard.render/1, %{
          static: static,
          state: %{state | static: static},
          ui: MishkaGervaz.UIAdapters.Tailwind,
          myself: nil,
          uploads: %{}
        })
      end)

    refute html =~ "gervaz-form-loading"
  end

  test "reads its label in the caller's locale" do
    Gettext.put_locale(@backend, "fa")

    assert render_form(:loading) |> loading_box() =~ "[fa:mishka_gervaz] Loading…"
  after
    Gettext.put_locale(@backend, "en")
  end
end

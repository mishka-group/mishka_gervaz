defmodule MishkaGervaz.Table.Templates.ErrorStateTest do
  @moduledoc """
  The table's error state, drawn by each built-in template through the renderer.

  When no read has succeeded and the last one failed, the template keeps what it draws around the
  rows (the table's filters, the gallery's file count) and draws the DSL's `error_state` where the
  rows go, through the resource's UI adapter, with a Retry that sends `"reload"` to the table. A
  read that fails after one has succeeded leaves the rows on screen.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Templates.{MediaGallery, Table}
  alias MishkaGervaz.Table.Web.{Renderer, State}
  alias MishkaGervaz.Test.Web.GatedItem

  @master %{id: "master-1", site_id: nil, role: :admin}

  defmodule ErrorAdapter do
    use MishkaGervaz.Behaviours.UIAdapter

    def error_state(assigns) do
      ~H"""
      <p data-testid="adapter-error">{@message}</p>
      """
    end
  end

  defp render_table(template, state_opts, static_opts \\ []) do
    state = State.init("items", GatedItem, @master)
    state = %{state | static: struct(state.static, static_opts)}

    state =
      State.update(
        state,
        Keyword.merge([template: template, loading: :error, has_initial_data?: false], state_opts)
      )

    render_component(&Renderer.render/1, %{
      table_state: state,
      streams: %{state.static.stream_name => []},
      myself: nil,
      __changed__: %{}
    })
  end

  for {template, kept} <- [{Table, ~s(id="items_gated_items-filter")}, {MediaGallery, "0 files"}] do
    describe "#{inspect(template)} after a first read that failed" do
      test "keeps what it draws around the rows and draws the error state with a Retry" do
        html = render_table(unquote(template), [])

        assert html =~ unquote(kept)
        assert html =~ "Error loading data"
        assert html =~ ~s(phx-click="reload")
        refute html =~ "No records found"
      end

      test "draws the error state through the resource's UI adapter" do
        html = render_table(unquote(template), [], ui_adapter: ErrorAdapter)

        assert html =~ ~s(data-testid="adapter-error")
      end

      test "draws no error state once a read has succeeded" do
        for loading <- [:loaded, :error] do
          html = render_table(unquote(template), loading: loading, has_initial_data?: true)

          refute html =~ ~s(phx-click="reload")
        end
      end
    end
  end
end

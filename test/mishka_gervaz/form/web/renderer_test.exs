defmodule MishkaGervaz.Form.Web.RendererTest do
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Renderer
  import MishkaGervaz.Test.FormWebHelpers
  import Phoenix.LiveViewTest

  defmodule MockFormTemplate do
    use Phoenix.Component

    def render(assigns) do
      has_uploads = is_map(assigns[:uploads])
      uploads_empty = assigns[:uploads] == %{}

      assigns =
        assigns
        |> assign(:has_uploads_assign, has_uploads)
        |> assign(:uploads_empty, uploads_empty)

      ~H"""
      <div data-testid="mock-form-template">
        <span data-static-id={@static.id}></span>
        <span data-has-uploads={to_string(@has_uploads_assign)}></span>
        <span data-uploads-empty={to_string(@uploads_empty)}></span>
        <span data-mode={to_string(@state.mode)}></span>
        <span data-loading={to_string(@state.loading)}></span>
        <span data-layout-mode={to_string(@static.layout_mode)}></span>
        <span data-upload-count={to_string(length(@static.uploads))}></span>
      </div>
      """
    end

    def render_loading(assigns) do
      ~H"""
      <div data-testid="mock-form-loading">Loading form...</div>
      """
    end
  end

  describe "render/1 with form_state" do
    test "dispatches to template render" do
      state = build_state(static_opts: [template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-testid="mock-form-template")
      assert result =~ ~s(data-static-id="test-form")
    end

    test "passes mode from state" do
      state = build_state(mode: :create, static_opts: [template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)
      assert result =~ ~s(data-mode="create")
    end

    test "passes update mode" do
      state = build_state(mode: :update, static_opts: [template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)
      assert result =~ ~s(data-mode="update")
    end

    test "assigns @uploads as empty map by default" do
      state = build_state(static_opts: [template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-has-uploads="true")
      assert result =~ ~s(data-uploads-empty="true")
    end

    test "preserves existing @uploads if already set" do
      state = build_state(static_opts: [template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}, uploads: %{avatar: :some_ref}}

      result = render_component(&Renderer.render/1, assigns)

      assert result =~ ~s(data-has-uploads="true")
      assert result =~ ~s(data-uploads-empty="false")
    end

    test "passes layout_mode from static" do
      state = build_state(static_opts: [template: MockFormTemplate, layout_mode: :wizard])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)
      assert result =~ ~s(data-layout-mode="wizard")
    end

    test "passes upload count from static" do
      uploads = [upload_config(:cover), upload_config(:docs)]
      state = build_state(static_opts: [template: MockFormTemplate, uploads: uploads])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)
      assert result =~ ~s(data-upload-count="2")
    end

    test "passes loading state" do
      state = build_state(loading: :loaded, static_opts: [template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)
      assert result =~ ~s(data-loading="loaded")
    end
  end

  describe "render/1 without form_state" do
    test "falls through to render_loading path" do
      state = build_state(static_opts: [template: MockFormTemplate])

      assigns = %{
        form_state: state,
        __changed__: %{}
      }

      result = render_component(&Renderer.render/1, assigns)
      refute result =~ "mock-form-loading"
      assert result =~ "mock-form-template"
    end
  end

  describe "render/1 with custom id" do
    test "passes custom id through static" do
      state = build_state(static_opts: [id: "post-editor", template: MockFormTemplate])
      assigns = %{form_state: state, __changed__: %{}}

      result = render_component(&Renderer.render/1, assigns)
      assert result =~ ~s(data-static-id="post-editor")
    end
  end
end

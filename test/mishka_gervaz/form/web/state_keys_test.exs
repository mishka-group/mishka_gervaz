defmodule MishkaGervaz.Form.Web.StateKeysTest do
  @moduledoc """
  A `:key_map` field whose keys come from the form state.

  One create form serves every source: the page opens it with the source in `defaults` and
  `reset: true`, and the field's `options fn state -> keys end` names that source's keys. Each
  opening draws the keys of its source, the params are read against those keys, a `required` key
  carries the required mark, and a `:password` key is drawn masked and never shows what it holds.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias MishkaGervaz.Form.Web.{Events, Live, Renderer}
  alias MishkaGervaz.Test.Resources.SourceConnection

  @user %{id: "user-1", site_id: nil}
  @id "source-connection"

  setup do
    SourceConnection |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    flush_send_updates()
    :ok
  end

  defp flush_send_updates do
    receive do
      {:phoenix, :send_update, _update} -> flush_send_updates()
    after
      0 -> :ok
    end
  end

  defp mount(source) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, flash: %{}},
      transport_pid: self()
    }

    {:ok, socket} =
      Live.update(
        %{
          id: @id,
          resource: SourceConnection,
          current_user: @user,
          defaults: %{source: source}
        },
        socket
      )

    socket
  end

  defp component_update(socket, assigns) do
    {:ok, socket} = Live.update(Map.put(assigns, :id, @id), socket)
    socket
  end

  defp deliver_send_updates(socket) do
    receive do
      {:phoenix, :send_update, {{Live, @id}, assigns}} ->
        socket |> component_update(assigns) |> deliver_send_updates()
    after
      0 -> socket
    end
  end

  # What a page sends to open the one form for another source.
  defp open_for(socket, source) do
    socket
    |> component_update(%{defaults: %{source: source}, reset: true})
    |> deliver_send_updates()
  end

  defp type_settings(socket, settings) do
    params = %{"form" => %{"settings" => settings}, "_target" => ["form", "settings"]}
    {:noreply, socket} = Events.handle("validate", params, socket)
    socket
  end

  defp save(socket) do
    params = %{"form" => socket.assigns.form_state.form.params}
    {:noreply, socket} = Events.handle("save", params, socket)
    socket
  end

  defp render_form(socket) do
    render_component(&Renderer.render/1, %{
      form_state: socket.assigns.form_state,
      __changed__: %{}
    })
  end

  defp setting_inputs(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|input[name^="form[settings]["]|)
    |> Enum.map(fn input ->
      [name] = LazyHTML.attribute(input, "name")
      name |> String.trim_leading("form[settings][") |> String.trim_trailing("]")
    end)
    |> Enum.uniq()
  end

  defp setting_input(html, key) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(~s|input[name="form[settings][#{key}]"]|)
  end

  defp attribute(node, name), do: node |> LazyHTML.attribute(name) |> List.first()

  describe "a key map whose keys come from the form state" do
    test "draws the keys of the source the page opened it with" do
      html = "wordpress" |> mount() |> render_form()

      assert setting_inputs(html) == ["url", "username", "app_password"]
    end

    test "draws another source's keys when the page opens it again for that source" do
      socket = "wordpress" |> mount() |> open_for("ghost")

      assert socket.assigns.form_state.defaults == %{source: "ghost"}
      assert setting_inputs(render_form(socket)) == ["api_url", "admin_api_key"]

      socket = open_for(socket, "wordpress")

      assert setting_inputs(render_form(socket)) == ["url", "username", "app_password"]
    end

    test "reads what is typed against the keys of its source, and saves them" do
      socket =
        "wordpress"
        |> mount()
        |> open_for("ghost")
        |> type_settings(%{
          "api_url" => "https://ghost.test",
          "admin_api_key" => "key-1",
          "url" => "https://not-a-ghost-key.test"
        })

      assert socket.assigns.form_state.form.source.params["settings"] == %{
               "api_url" => "https://ghost.test",
               "admin_api_key" => "key-1"
             }

      save(socket)

      assert [record] = Ash.read!(SourceConnection)
      assert record.source == "ghost"
      assert record.settings == %{"api_url" => "https://ghost.test", "admin_api_key" => "key-1"}
    end

    test "marks a required key as the form marks a required field" do
      html = "wordpress" |> mount() |> render_form()
      doc = LazyHTML.from_fragment(html)

      required_labels =
        doc
        |> LazyHTML.query("label:has(span)")
        |> Enum.filter(&(&1 |> LazyHTML.query("span") |> LazyHTML.text() == "*"))
        |> Enum.map(&attribute(&1, "for"))

      url_id = html |> setting_input("url") |> attribute("id")
      password_id = html |> setting_input("app_password") |> attribute("id")
      username_id = html |> setting_input("username") |> attribute("id")

      assert url_id in required_labels
      assert password_id in required_labels
      refute username_id in required_labels
    end
  end

  describe "a password key" do
    test "is a password input that does not fill itself in" do
      html = "wordpress" |> mount() |> render_form()
      input = setting_input(html, "app_password")

      assert attribute(input, "type") == "password"
      assert attribute(input, "autocomplete") == "off"
    end

    test "never shows the value it holds" do
      socket = "wordpress" |> mount() |> type_settings(%{"app_password" => "s3cret-pass"})

      assert socket.assigns.form_state.form.source.params["settings"] == %{
               "app_password" => "s3cret-pass"
             }

      html = render_form(socket)

      assert attribute(setting_input(html, "app_password"), "value") in [nil, ""]
      refute html =~ "s3cret-pass"
    end

    # A password key is not filled in from the server, so the client must keep what is typed into
    # it across the renders that follow; each start over draws it anew so nothing typed outlives a
    # save, a Cancel or a reset.
    test "keeps what is typed while the form is open, and is empty again when it starts over" do
      socket = mount("wordpress")
      opened = password_box(render_form(socket), "app_password")

      socket =
        type_settings(socket, %{"app_password" => "s3cret-pass", "url" => "https://wp.test"})

      assert password_box(render_form(socket), "app_password") == opened
      assert {_id, "ignore"} = opened

      socket = open_for(socket, "wordpress")

      assert {other_id, "ignore"} = password_box(render_form(socket), "app_password")
      refute other_id == elem(opened, 0)
    end
  end

  defp password_box(html, key) do
    box =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(~s|[phx-update]:has(> input[name="form[settings][#{key}]"])|)

    {attribute(box, "id"), attribute(box, "phx-update")}
  end
end

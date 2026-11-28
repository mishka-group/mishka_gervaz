defmodule MishkaGervaz.Form.Web.UploadSubmitLiveTest do
  @moduledoc """
  A file dropped on `MishkaGervaz.Test.Web.CratePageLive`'s form and saved: the action gets the
  file at a path the form made up and the client's name as plain data.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Test.Web.CrateItem

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @form "#crate-form"

  setup do
    on_exit(fn -> CrateItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
  end

  defp open do
    {:ok, view, _html} = live(build_conn(), "/crates")
    render_async(view)
    view
  end

  defp drop(view, name, content) do
    manifest =
      file_input(view, @form, :manifest_crate, [
        %{name: name, content: content, type: "text/plain"}
      ])

    render_upload(manifest, name)
    view
  end

  defp save(view, values),
    do: view |> form(@form, %{"form" => values}) |> render_submit()

  defp remove_file(view) do
    view
    |> element(~s|#crate-form button[phx-click="cancel_upload"]|)
    |> render_click()

    view
  end

  describe "a save that fails" do
    test "keeps the dropped file, so the next save hands it over" do
      view = open() |> drop("manifest.txt", "first contents")

      save(view, %{"title" => ""})
      assert Ash.read!(CrateItem) == []
      assert has_element?(view, ~s|#crate-form button[phx-click="cancel_upload"]|)

      save(view, %{"title" => "Spare parts"})

      assert [crate] = Ash.read!(CrateItem)
      assert crate.manifest_name == "manifest.txt"
      assert crate.manifest_body == "first contents"
      refute has_element?(view, ~s|#crate-form button[phx-click="cancel_upload"]|)
    end

    test "then a removed file is not handed over and the save goes through" do
      view = open() |> drop("manifest.txt", "first contents")

      save(view, %{"title" => ""})
      view |> remove_file() |> save(%{"title" => "Spare parts"})

      assert [crate] = Ash.read!(CrateItem)
      assert crate.manifest_name == nil
    end

    test "then a file dropped in place of the first is the one handed over" do
      view = open() |> drop("manifest.txt", "first contents")

      save(view, %{"title" => ""})
      view |> remove_file() |> drop("second.txt", "second contents")
      save(view, %{"title" => "Spare parts"})

      assert [crate] = Ash.read!(CrateItem)
      assert crate.manifest_name == "second.txt"
      assert crate.manifest_body == "second contents"
    end
  end

  describe "a client name that is not a plain file name" do
    for {name, safe} <- [
          {"../../etc/passwd", "passwd"},
          {"docs/readme.txt", "readme.txt"},
          {"<b>x</b>.txt", "b>.txt"},
          {"..\\..\\boot.ini", "boot.ini"},
          {"line\nbreak\u0000.txt", "linebreak.txt"}
        ] do
      test "#{inspect(name)} is saved with the file handed over and the name kept as #{safe}" do
        view = open() |> drop(unquote(name), "crate contents")

        save(view, %{"title" => "Spare parts"})

        assert [crate] = Ash.read!(CrateItem)
        assert crate.manifest_name == unquote(safe)
        assert crate.manifest_body == "crate contents"
        assert Path.dirname(crate.manifest_path) == Path.expand(System.tmp_dir!())
        refute String.contains?(crate.manifest_path, unquote(safe))
        refute File.exists?(crate.manifest_path)
      end
    end
  end
end

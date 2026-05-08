defmodule MishkaGervaz.Form.Types.Field.ComboboxTest do
  @moduledoc "Direct tests for the `:combobox` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.Combobox

  test "render/2" do
    assert Combobox.render(%{}, %{}) == %{}
  end

  test "validate/2 passes through (free-text + suggestion list)" do
    assert Combobox.validate("custom", %{}) == {:ok, "custom"}
    assert Combobox.validate("", %{}) == {:ok, ""}
    assert Combobox.validate(nil, %{}) == {:ok, nil}
  end

  test "parse_params/2 passes through" do
    assert Combobox.parse_params("v", %{}) == "v"
  end

  describe "sanitize/2" do
    test "strips HTML and trims binaries" do
      assert Combobox.sanitize(" <b>en</b> ", %{}) == "en"
    end

    test "passes non-binaries through" do
      assert Combobox.sanitize(:atom, %{}) == :atom
      assert Combobox.sanitize(nil, %{}) == nil
    end
  end

  test "default_ui/0" do
    assert Combobox.default_ui() == %{type: :combobox}
  end
end

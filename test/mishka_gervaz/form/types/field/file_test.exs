defmodule MishkaGervaz.Form.Types.Field.FileTest do
  @moduledoc "Direct tests for the `:file` field type."
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Types.Field.File, as: FieldFile

  test "render/2" do
    assert FieldFile.render(%{}, %{}) == %{}
  end

  test "validate/2 passes through" do
    assert FieldFile.validate(%{path: "/tmp/x.png"}, %{}) == {:ok, %{path: "/tmp/x.png"}}
    assert FieldFile.validate(nil, %{}) == {:ok, nil}
  end

  test "parse_params/2 passes through" do
    assert FieldFile.parse_params("v", %{}) == "v"
  end

  test "sanitize/2 passes through" do
    assert FieldFile.sanitize("v", %{}) == "v"
  end

  test "default_ui/0" do
    assert FieldFile.default_ui() == %{type: :file}
  end
end

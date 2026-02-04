defmodule MishkaGervaz.HelpersTest do
  @moduledoc """
  Tests for the MishkaGervaz.Helpers module.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Helpers

  describe "humanize/1" do
    test "converts atom with underscores to title case" do
      assert Helpers.humanize(:first_name) == "First Name"
    end

    test "converts simple atom to capitalized string" do
      assert Helpers.humanize(:name) == "Name"
    end

    test "handles atom with multiple underscores" do
      assert Helpers.humanize(:user_profile_id) == "User Profile Id"
    end

    test "handles atom ending with _id" do
      assert Helpers.humanize(:user_id) == "User Id"
    end

    test "returns string as-is" do
      assert Helpers.humanize("already_formatted") == "already_formatted"
    end

    test "returns empty string for empty string" do
      assert Helpers.humanize("") == ""
    end

    test "handles single character atom" do
      assert Helpers.humanize(:a) == "A"
    end

    test "handles atom with numbers" do
      assert Helpers.humanize(:field_1) == "Field 1"
    end

    test "handles atom with consecutive underscores" do
      assert Helpers.humanize(:some__field) == "Some Field"
    end
  end
end

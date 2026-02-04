defmodule MishkaGervaz.DSL.RealtimeTest do
  @moduledoc """
  Tests for the realtime section of the MishkaGervaz DSL.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.Post

  describe "realtime configuration" do
    test "realtime config is present" do
      config = ResourceInfo.table_config(Post)
      assert config.realtime != nil
    end

    test "realtime has enabled key" do
      config = ResourceInfo.table_config(Post)
      assert Map.has_key?(config.realtime, :enabled)
    end

    test "realtime config structure" do
      config = ResourceInfo.table_config(Post)
      # Realtime should be a map with expected keys
      assert is_map(config.realtime)
    end
  end
end

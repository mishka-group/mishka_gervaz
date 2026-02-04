defmodule MishkaGervaz.DSL.IdentityTest do
  @moduledoc """
  Tests for the identity section of the MishkaGervaz DSL.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.ResourceInfo
  alias MishkaGervaz.Test.Resources.{Post, User, Comment}

  describe "identity configuration" do
    test "returns correct name for resource" do
      config = ResourceInfo.table_config(Post)
      assert config.identity.name == :posts
    end

    test "returns correct route for resource" do
      config = ResourceInfo.table_config(Post)
      assert config.identity.route == "/admin/posts"
    end

    test "returns stream_name when configured" do
      assert ResourceInfo.stream_name(Post) == :posts_stream
    end

    test "stream_name returns atom when configured" do
      # All test resources have stream_name, so just verify it's an atom
      stream_name = ResourceInfo.stream_name(Post)
      assert is_atom(stream_name)
    end

    test "User resource has correct identity" do
      config = ResourceInfo.table_config(User)
      assert config.identity.name == :users
      assert config.identity.route == "/admin/users"
    end

    test "Comment resource has correct identity" do
      config = ResourceInfo.table_config(Comment)
      assert config.identity.name == :comments
      assert config.identity.route == "/admin/comments"
    end
  end
end

defmodule MishkaGervaz.Form.DSL.IdentityTest do
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.{FormPost, MinimalForm}

  describe "explicit identity" do
    test "name is configured" do
      config = FormInfo.config(FormPost)
      assert config.identity.name == :form_post
    end

    test "route is configured" do
      config = FormInfo.config(FormPost)
      assert config.identity.route == "/admin/posts"
    end

    test "stream_name is auto-derived from name" do
      config = FormInfo.config(FormPost)
      assert config.identity.stream_name == :form_post_stream
    end
  end

  describe "auto-derived identity" do
    test "name is derived from module when not set" do
      config = FormInfo.config(MinimalForm)
      assert is_atom(config.identity.name)
      assert config.identity.name != nil
    end

    test "stream_name is derived from name" do
      config = FormInfo.config(MinimalForm)
      name = config.identity.name
      assert config.identity.stream_name == String.to_atom("#{name}_stream")
    end

    test "route is nil when not set" do
      config = FormInfo.config(MinimalForm)
      assert config.identity.route == nil
    end
  end

  describe "info accessors" do
    test "stream_name/1" do
      assert FormInfo.stream_name(FormPost) == :form_post_stream
    end

    test "route/1" do
      assert FormInfo.route(FormPost) == "/admin/posts"
    end

    test "route/1 returns nil for minimal" do
      assert FormInfo.route(MinimalForm) == nil
    end
  end
end

defmodule MishkaGervaz.Form.Transformers.MergeDefaultsTest do
  @moduledoc """
  Tests for the MergeDefaults transformer.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias Spark.Dsl.Extension

  alias MishkaGervaz.Test.Resources.{
    MinimalForm,
    NoMasterCheckForm
  }

  describe "MinimalForm identity auto-derivation" do
    test "name is auto-derived from module" do
      config = FormInfo.config(MinimalForm)
      assert is_atom(config.identity.name)
      assert config.identity.name != nil
    end

    test "stream_name is auto-derived from name" do
      config = FormInfo.config(MinimalForm)
      name = config.identity.name
      assert config.identity.stream_name == String.to_atom("#{name}_stream")
    end
  end

  describe "default master_check MFA" do
    test "default master_check is persisted when not set" do
      persisted =
        Extension.get_persisted(
          NoMasterCheckForm,
          :mishka_gervaz_form_default_master_check
        )

      # The default MFA is persisted as a tuple
      assert is_tuple(persisted)
      assert elem(persisted, 0) == MishkaGervaz.Table.Defaults
      assert elem(persisted, 1) == :default_master_check
    end

    test "resolved master_check is a function on NoMasterCheckForm" do
      config = FormInfo.config(NoMasterCheckForm)
      assert is_function(config.source.master_check, 1)
    end
  end

  describe "actor_key defaults" do
    test "defaults to :current_user when not explicitly set" do
      config = FormInfo.config(MinimalForm)
      assert config.source.actor_key == :current_user
    end
  end
end

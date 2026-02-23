defmodule MishkaGervaz.Form.Verifiers.ValidateSourceTest do
  @moduledoc """
  Tests for the ValidateSource verifier.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.NoMasterCheckForm

  describe "positive: default master_check fallback" do
    test "NoMasterCheckForm compiles with default fallback" do
      config = FormInfo.config(NoMasterCheckForm)
      assert config != nil
      assert is_function(config.source.master_check, 1)
    end

    test "NoMasterCheckForm action tuples are preserved" do
      config = FormInfo.config(NoMasterCheckForm)
      assert config.source.actions.create == {:master_create, :create}
      assert config.source.actions.update == {:master_update, :update}
      assert config.source.actions.read == {:master_get, :read}
    end
  end
end

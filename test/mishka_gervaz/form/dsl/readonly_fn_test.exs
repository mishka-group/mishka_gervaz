defmodule MishkaGervaz.Form.DSL.ReadonlyFnTest do
  @moduledoc """
  Tests for field `readonly` accepting boolean or function.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Test.Resources.ReadonlyFnForm

  describe "readonly as function" do
    test "title field has readonly as function/1" do
      field = FormInfo.field(ReadonlyFnForm, :title)
      assert is_function(field.readonly, 1)
    end

    test "readonly fn returns true for non-master state" do
      field = FormInfo.field(ReadonlyFnForm, :title)
      assert field.readonly.(%{master_user?: false}) == true
    end

    test "readonly fn returns false for master state" do
      field = FormInfo.field(ReadonlyFnForm, :title)
      assert field.readonly.(%{master_user?: true}) == false
    end
  end

  describe "readonly as boolean" do
    test "content field has readonly as true" do
      field = FormInfo.field(ReadonlyFnForm, :content)
      assert field.readonly == true
    end

    test "status field has readonly as false" do
      field = FormInfo.field(ReadonlyFnForm, :status)
      assert field.readonly == false
    end
  end
end

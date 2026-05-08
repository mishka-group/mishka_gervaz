defmodule MishkaGervaz.Form.Web.DataLoader.RecordLoaderTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.DataLoader.RecordLoader.Default` and
  the public top-level helpers (`keyword_put_if_set/3`, `resolve_tenant_from_record/2`).
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.DataLoader.RecordLoader

  describe "keyword_put_if_set/3" do
    test "no-op when value is nil" do
      assert RecordLoader.keyword_put_if_set([a: 1], :tenant, nil) == [a: 1]
    end

    test "puts the value when not nil" do
      assert RecordLoader.keyword_put_if_set([a: 1], :tenant, "site-1") ==
               [tenant: "site-1", a: 1]
    end

    test "passes false / 0 / empty string through (only nil is filtered)" do
      assert RecordLoader.keyword_put_if_set([], :flag, false) == [flag: false]
      assert RecordLoader.keyword_put_if_set([], :n, 0) == [n: 0]
      assert RecordLoader.keyword_put_if_set([], :s, "") == [s: ""]
    end
  end

  describe "resolve_tenant_from_record/2" do
    test "returns nil for resources without multitenancy" do
      assert RecordLoader.resolve_tenant_from_record(MishkaGervaz.Test.Resources.FormPost, %{
               site_id: "uuid"
             }) == nil
    end

    test "returns the value of the multitenancy attribute when configured" do
      defmodule TestTenantedResource do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          data_layer: Ash.DataLayer.Ets

        ets do
          private? true
        end

        attributes do
          uuid_primary_key :id
          attribute :site_id, :uuid, public?: true
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        multitenancy do
          strategy :attribute
          attribute :site_id
        end
      end

      record = %{site_id: "uuid-1", name: "Acme"}

      assert RecordLoader.resolve_tenant_from_record(TestTenantedResource, record) ==
               "uuid-1"
    end
  end
end

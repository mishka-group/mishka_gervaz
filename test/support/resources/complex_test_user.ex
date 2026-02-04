defmodule MishkaGervaz.Test.Resources.ComplexTestUser do
  @moduledoc """
  Test user resource for relationship testing in complex DSL tests.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.ComplexTestDomain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      default :user
      public? true
    end
  end
end

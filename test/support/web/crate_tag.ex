defmodule MishkaGervaz.Test.Web.CrateTag do
  @moduledoc """
  A tag a `MishkaGervaz.Test.Web.CrateItem` carries by id in `:tag_ids`. Only an `:active` tag is
  offered in the crate form's tag field.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read, :destroy, create: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :active, :boolean, default: true, public?: true
  end
end

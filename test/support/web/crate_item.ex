defmodule MishkaGervaz.Test.Web.CrateItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.CratePageLive`'s form: a crate a person files.

    * `:title` — a required text field;
    * `:manifest` — an upload that names no `accept`, so it takes a file of any type.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :crate_items
        route "/crates"
      end

      source do
        actions do
          create {:create, :create}
          update {:update, :update}
          read {:read, :read}
        end
      end

      fields do
        field :title, :text, required: true
        field :manifest, :upload
      end

      uploads do
        upload :manifest do
          max_entries 1
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
  end
end

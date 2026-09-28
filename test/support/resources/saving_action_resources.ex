defmodule MishkaGervaz.Test.Resources.RaisingCreate do
  @moduledoc """
  A create action whose change raises while the changeset is built.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  actions do
    defaults [:read, update: [:title]]

    create :create do
      accept [:title]
      change fn _changeset, _context -> raise "the change failed" end
    end
  end
end

defmodule MishkaGervaz.Test.Resources.CreateOnlyNote do
  @moduledoc """
  A form that only creates: it has no update action and closes `:update` with `access :update, false`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :create_only_note
        route "/admin/create-only-notes"
      end

      source do
        actions do
          create :create
          read :read
        end

        access :update, false
      end

      fields do
        field :body, :text
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :body, :string, public?: true
  end

  actions do
    defaults [:read, create: [:body]]
  end
end

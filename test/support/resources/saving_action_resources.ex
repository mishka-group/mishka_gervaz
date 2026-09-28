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

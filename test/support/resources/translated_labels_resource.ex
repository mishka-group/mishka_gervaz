defmodule MishkaGervaz.Test.Resources.TranslatedLabels do
  @moduledoc """
  A resource whose form field and table column labels go through Gettext, for the tests that read
  an error message in another language.

  `:title` has a form field label and a different column label, `:slug` only a column label, and
  `:category_id` none.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  use MishkaGervaz.Messages

  mishka_gervaz do
    table do
      identity do
        name :translated_labels
        route "/admin/translated-labels"
      end

      columns do
        column :title do
          label fn -> dgettext("mishka_gervaz", "Heading") end
        end

        column :slug do
          label fn -> dgettext("mishka_gervaz", "Web address") end
        end
      end
    end

    form do
      identity do
        name :translated_labels_form
        route "/admin/translated-labels"
      end

      source do
        actions do
          create {:create, :create}
          update {:update, :update}
          read {:read, :read}
        end
      end

      fields do
        field :title, :text do
          ui do
            label fn -> dgettext("mishka_gervaz", "Post title") end
          end
        end
      end
    end
  end

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :slug, :string, public?: true
    attribute :category_id, :uuid, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read
    read :master_get
  end
end

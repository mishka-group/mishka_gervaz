defmodule MishkaGervaz.Test.Web.ShelfItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/shelf` table: a numbered list of three
  rows a page, sorted by title, whose rows open `/shelf/<id>`. Its rows can be picked, and each has a
  Delete action. It may be drawn as a table or a media gallery, but draws no switcher between them
  (`template_options switcher: false`); its template is synced to the URL.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :shelf_items
        route "/shelf"
        stream_name :shelf_items
      end

      columns do
        default_sort title: :asc

        column :title
      end

      pagination do
        type :numbered
        page_size 3
      end

      row do
        selectable true
        path fn record -> "/shelf/#{record.id}" end
      end

      row_actions do
        action :delete, type: :destroy
      end

      bulk_actions do
        action :wipe, type: :destroy
      end

      presentation do
        switchable_templates [
          MishkaGervaz.Table.Templates.Table,
          MishkaGervaz.Table.Templates.MediaGallery
        ]

        template_options switcher: false
      end

      url_sync do
        enabled true
        mode :bidirectional
        params [:template]
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      pagination offset?: true, keyset?: true, countable: true
    end

    read :master_get
    read :tenant_read
    destroy :master_destroy
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

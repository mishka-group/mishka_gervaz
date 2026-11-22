defmodule MishkaGervaz.Test.Web.DeskItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.TablePageLive`'s `/desk` table: a numbered list of five
  rows a page, sorted by title, with a form of its `:title` and `:owner`. Its row actions open the
  row in the table's drawer:

    * `:peek` — the record view of `MishkaGervaz.Test.Web.DeskViews.peek/1` in a drawer whose head
      has an icon tile, the title, a sub line and a chip, and a Copy button among its actions;
    * `:edit_here` — the resource's form, editing the row, in a bottom sheet.

  Its other actions ask in the table's question window before they run:

    * `:remove` — deletes the row once its title is typed, "Delete <title>?";
    * `:mark` — sends the page `{:row_action, "mark", payload}` after "Mark it?", in the info tone;
    * the bulk `:wipe` — deletes the picked rows after "Delete <count> items?".

  Its form asks "Save the item?" before every save of an edit.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  alias MishkaGervaz.Test.Web.DeskViews

  mishka_gervaz do
    table do
      identity do
        name :desk_items
        route "/desk"
        stream_name :desk_items
      end

      columns do
        default_sort title: :asc

        column :title
      end

      pagination do
        type :numbered
        page_size 5
      end

      row_actions do
        action :peek,
          type: :drawer,
          open: &DeskViews.peek/1,
          drawer: [
            title: &DeskViews.title/1,
            sub: &DeskViews.sub/1,
            icon: "hero-document-text",
            tone: :ok,
            chips: &DeskViews.chips/1,
            actions: &DeskViews.actions/1
          ]

        action :edit_here, type: :drawer, open: :form, drawer: [kind: :sheet, title: "Edit item"]

        action :remove,
          type: :destroy,
          confirm: [
            title: &DeskViews.delete_title/1,
            body: "It cannot be undone.",
            answer: &DeskViews.title/1,
            confirm_label: "Delete"
          ]

        action :mark,
          type: :event,
          event: "mark",
          confirm: [title: "Mark it?", tone: :info, cancel_label: "Not now"]
      end

      row do
        selectable true
      end

      bulk_actions do
        action :wipe,
          type: :destroy,
          confirm: [title: "Delete {count} items?", confirm_label: "Delete them"]
      end
    end

    form do
      identity do
        name :desk_items
        route "/desk"
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
        field :owner, :text
      end

      submit do
        update label: "Save",
               confirm: [
                 title: "Save the item?",
                 body: &DeskViews.save_body/1,
                 tone: :warn,
                 confirm_label: "Save it"
               ]
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
    attribute :owner, :string, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Web.DeskViews do
  @moduledoc """
  What `MishkaGervaz.Test.Web.DeskItem`'s `:peek` drawer draws for a row: its head's title, sub
  line, chips and actions, and its body, the record view.
  """

  use Phoenix.Component

  @doc "The drawer's title: the row's title."
  def title(record), do: record.title

  @doc "The question the `:remove` action asks."
  def delete_title(record), do: "Delete #{record.title}?"

  @doc "The sentence of the form's question: the title of the record it edits."
  def save_body(%{title: title}), do: "The changes to #{title} are saved."
  def save_body(nil), do: "A new item is made."

  @doc "The line under the title: whose the row is."
  def sub(record), do: "Owned by #{record.owner || "nobody"}"

  @doc "A chip saying whether the row has an owner."
  def chips(%{owner: nil}), do: [{:warn, "No owner"}]
  def chips(_record), do: [{:ok, "Owned"}]

  @doc "The drawer's buttons: one that sends the page `copy_item` with the row's id."
  def actions(record) do
    assigns = %{record: record}

    ~H"""
    <button id="copy-item" type="button" phx-click="copy_item" phx-value-id={@record.id}>
      Copy
    </button>
    """
  end

  @doc "The record view: the row's title and id."
  def peek(record) do
    assigns = %{record: record}

    ~H"""
    <dl id="peek-view">
      <dt>Title</dt>
      <dd id="peek-title">{@record.title}</dd>
      <dt>Id</dt>
      <dd id="peek-id">{@record.id}</dd>
    </dl>
    """
  end
end

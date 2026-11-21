defmodule MishkaGervaz.Test.Web.PlacedItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.PlacedPageLive`'s form, a `:standard` form whose page
  places its groups (`MishkaGervaz.Form.Web.Live.group/1`):

    * `:basics` — `:title`, required;
    * `:keys` — `:licensed`, a `:toggle`, and `:places`, a number from 1 to 10 drawn only while
      `:licensed` is on, with a notice after the group;
    * `:note` — a text field in no group.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :placed_items
        route "/placed"
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

        field :licensed, :toggle do
          ui do
            label "Make a key"
          end
        end

        field :places, :number do
          min 1
          max 10

          visible fn
            %{form: nil} -> false
            %{form: form} -> Phoenix.HTML.Form.input_value(form, :licensed) in [true, "true"]
          end
        end

        field :note, :text
      end

      groups do
        group :basics do
          fields [:title]
        end

        group :keys do
          fields [:licensed, :places]
        end
      end

      layout do
        notice :keys_help do
          position {:after_group, :keys}
          type :info
          title "A key is sent with the receipt"
        end
      end

      submit do
        discard label: "Discard"
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :licensed, :boolean, default: false, public?: true
    attribute :places, :integer, default: 2, constraints: [min: 1, max: 10], public?: true
    attribute :note, :string, public?: true
  end
end

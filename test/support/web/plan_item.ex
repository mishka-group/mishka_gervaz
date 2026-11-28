defmodule MishkaGervaz.Test.Web.PlanItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.PlanPageLive`'s form: a price plan, a `:tabs` form with
  `navigation :free` and three tabs, Basics (`:title`, `:kind`, `:billing`), Pricing (`:slug`,
  `:price`, `:discount`) and Publishing (`:listed`, `:featured`, `:channels`). Its `before_save`
  fills an empty slug from the title. Its submit row has a Discard button,
  and its Cancel and Discard ask "Discard your changes?" while the form holds changes. A notice
  above the submit row, `:shop`, names the shop in the page's `defaults` while it gives one.

    * `:kind` — a `:choice_cards` field: One-time, with a second line and an icon, and
      Subscription;
    * `:billing` — a `:segmented` field: Monthly and Yearly, Yearly with a second line;
    * `:slug` — a text field with the prefix `/products/`;
    * `:price` — a decimal number with the prefix `USD`, from `0.50` to `9999.99`;
    * `:discount` — a whole number with the suffix `%`;
    * `:listed` — a `:toggle` with a note beside it and help text under it;
    * `:featured` — a `:checkbox` with a note beside it;
    * `:channels` — a `:multi_select` over `{:array, :atom}`, its options with second lines.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :plan_items
        route "/plans"
      end

      source do
        actions do
          create {:create, :create}
          update {:update, :update}
          read {:read, :read}
        end
      end

      hooks do
        before_save fn %{"form" => values} = params, _state ->
          case values do
            %{"slug" => slug, "title" => title} when slug in [nil, ""] ->
              put_in(params, ["form", "slug"], String.downcase(title))

            _values ->
              params
          end
        end
      end

      fields do
        field :title, :text, required: true

        field :kind, :choice_cards do
          options [
            [
              label: "One-time",
              value: :one_time,
              description: "Pay once, keep it",
              icon: "hero-bolt"
            ],
            [label: "Subscription", value: :subscription]
          ]
        end

        field :billing, :segmented do
          options [
            {"Monthly", :monthly},
            [label: "Yearly", value: :yearly, description: "Two months free"]
          ]
        end

        field :slug, :text do
          ui do
            prefix "/products/"
          end
        end

        field :price, :number do
          min Decimal.new("0.50")
          max fn -> Decimal.new("9999.99") end

          ui do
            prefix "USD"
            step 0.01
          end
        end

        field :discount, :number do
          ui do
            suffix fn -> "%" end
          end
        end

        field :listed, :toggle do
          ui do
            label "Listed"
            note "Buyers find it in the store"
            description "Turn it off to keep a draft"
          end
        end

        field :featured, :checkbox do
          ui do
            note fn -> "Shown first on the home page" end
          end
        end

        field :channels, :multi_select do
          options [
            [label: "Store", value: :store, description: "The public store page"],
            [label: "Email", value: :email, description: "The newsletter"],
            {"Feed", :feed}
          ]
        end
      end

      submit do
        cancel label: "Cancel", confirm: "Discard your changes?"
        discard label: "Discard", confirm: fn -> "Discard your changes?" end
      end

      groups do
        group :basics do
          fields [:title, :kind, :billing]
        end

        group :pricing do
          fields [:slug, :price, :discount]
        end

        group :publishing do
          fields [:listed, :featured, :channels]
        end
      end

      layout do
        mode :tabs
        navigation :free

        notice :shop do
          position :before_submit
          type :info
          visible fn state -> is_map(state.defaults) and Map.has_key?(state.defaults, :shop) end
          title fn state -> "Sold in #{state.defaults.shop}" end
        end

        step :basics do
          groups [:basics]

          ui do
            label "Basics"
          end
        end

        step :pricing do
          groups [:pricing]

          ui do
            label "Pricing"
            icon "hero-banknotes"
          end
        end

        step :publishing do
          groups [:publishing]

          ui do
            label "Publishing"
          end
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

    attribute :kind, :atom,
      constraints: [one_of: [:one_time, :subscription]],
      default: :one_time,
      public?: true

    attribute :billing, :atom, constraints: [one_of: [:monthly, :yearly]], public?: true
    attribute :slug, :string, public?: true
    attribute :price, :decimal, public?: true
    attribute :discount, :integer, public?: true
    attribute :listed, :boolean, default: false, public?: true
    attribute :featured, :boolean, default: false, public?: true

    attribute :channels, {:array, :atom},
      constraints: [items: [one_of: [:store, :email, :feed]]],
      default: [],
      public?: true
  end
end

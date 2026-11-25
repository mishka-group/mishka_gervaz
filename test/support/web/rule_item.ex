defmodule MishkaGervaz.Test.Web.RuleItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.RulePageLive`'s form: one page of fields that each carry a
  rule a person can break, to check what the form says when one is broken.

    * `:name` — a required text field, up to 20 characters by its attribute's `max_length`;
    * `:note` — a textarea, up to 40 characters by its attribute's `max_length`;
    * `:seats` — a required whole number, from 1 to 10 by its attribute's `min` and `max`
      constraints only, with no bound in the form;
    * `:budget` — a number the form bounds with `max 100`, whose action also refuses more than 100
      in its own sentence, "Use 100 or less: that is the budget.";
    * `:contacts` — a list of maps with a required `person` key and a `phone` key.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :rule_items
        route "/rules"
      end

      source do
        actions do
          create {:create, :create}
          update {:update, :update}
          read {:read, :read}
        end
      end

      fields do
        field :name, :text do
          required true

          ui do
            label "Name"
          end
        end

        field :note, :textarea do
          ui do
            label "Note"
          end
        end

        field :seats, :number do
          required true

          ui do
            label "Seats"
          end
        end

        field :budget, :number do
          max 100

          ui do
            label "Budget"
          end
        end

        field :contacts do
          ui do
            label "Contacts"
          end
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept :*

      validate fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :budget) do
          %Decimal{} = budget ->
            if Decimal.gt?(budget, 100),
              do: {:error, field: :budget, message: "Use 100 or less: that is the budget."},
              else: :ok

          _none ->
            :ok
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 20]
    attribute :note, :string, public?: true, constraints: [max_length: 40]
    attribute :seats, :integer, allow_nil?: false, public?: true, constraints: [min: 1, max: 10]
    attribute :budget, :decimal, public?: true

    attribute :contacts, {:array, :map} do
      default []
      public? true

      constraints items: [
                    fields: [person: [type: :string, allow_nil?: false], phone: [type: :string]]
                  ]
    end
  end
end

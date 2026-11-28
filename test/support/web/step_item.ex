defmodule MishkaGervaz.Test.Web.StepItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.StepPageLive`'s wizard, whose first step saves: three
  steps.

    * `:basics` — the title, required; the step says `save true`, so Next saves the record;
    * `:content` — the body, also `save true`; the step the page adds its own markup to;
    * `:review` — the note.

  Its update refuses the body `refused` only when it runs, never while the form validates.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :step_items
        route "/steps"
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
        field :body, :text
        field :note, :text
      end

      groups do
        group :basics do
          fields [:title]
        end

        group :content do
          fields [:body]
        end

        group :review do
          fields [:note]
        end
      end

      layout do
        mode :wizard

        step :basics do
          groups [:basics]
          save(true)

          ui do
            label "Basics"
          end
        end

        step :content do
          groups [:content]
          save(true)

          ui do
            label "Content"
          end
        end

        step :review do
          groups [:review]

          ui do
            label "Review"
          end
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*]

    update :update do
      primary? true
      accept [:title, :body, :note]
      require_atomic? false

      change before_action(fn changeset, _context ->
               case Ash.Changeset.get_attribute(changeset, :body) do
                 "refused" ->
                   Ash.Changeset.add_error(changeset, field: :body, message: "Not this body.")

                 _body ->
                   changeset
               end
             end)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, public?: true
    attribute :note, :string, public?: true
  end
end

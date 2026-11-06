defmodule MishkaGervaz.Test.Web.WizardItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.FormPageLive`'s wizard: three steps.

    * `:where` — the title and the address, both required;
    * `:what` — the kind, a select, and the language, a select whose options are a function of the
      form state: a "Page language" choice is offered only while the kind is `page`;
    * `:review` — the note, in the `:advanced` group, which starts collapsed.

  Its create refuses the address `refused.example` only when it runs, never while the form
  validates, as a source that does not answer refuses a connection. Its Save button reads
  "Checking the address…" while the save runs.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :wizard_items
        route "/wizard"
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
        field :address, :text, required: true

        field :kind, :select do
          options [{"Post", "post"}, {"Page", "page"}]
        end

        field :language, :select do
          options fn state -> MishkaGervaz.Test.Web.WizardItem.languages(state) end
        end

        field :note, :text
      end

      groups do
        group :where do
          fields [:title, :address]
        end

        group :what do
          fields [:kind, :language]
        end

        group :advanced do
          fields [:note]
          collapsed true

          ui do
            label "Advanced"
          end
        end
      end

      submit do
        create label: "Save", loading_label: "Checking the address…"
      end

      layout do
        mode :wizard

        step :where do
          groups [:where]

          ui do
            label "Where from"
          end
        end

        step :what do
          groups [:what]

          ui do
            label "What to bring"
          end
        end

        step :review do
          groups [:advanced]

          ui do
            label "Review"
          end
        end
      end
    end
  end

  @doc "The language options: English and Deutsch, and Page language while the kind is `page`."
  @spec languages(map()) :: [{String.t(), String.t()}]
  def languages(%{form: %{params: %{"kind" => "page"}}}),
    do: [{"English", "en"}, {"Deutsch", "de"}, {"Page language", "page"}]

  def languages(_state), do: [{"English", "en"}, {"Deutsch", "de"}]

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:title, :address, :kind, :language, :note]

      change before_action(fn changeset, _context ->
               case Ash.Changeset.get_attribute(changeset, :address) do
                 "refused.example" ->
                   Ash.Changeset.add_error(changeset,
                     field: :address,
                     message: "Nothing answered at this address."
                   )

                 _address ->
                   changeset
               end
             end)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :address, :string, allow_nil?: false, public?: true
    attribute :kind, :string, public?: true
    attribute :language, :string, public?: true
    attribute :note, :string, public?: true
  end
end

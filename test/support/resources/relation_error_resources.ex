defmodule MishkaGervaz.Test.Resources.RelationErrorLabel do
  @moduledoc """
  A label an article picks through `MishkaGervaz.Test.Resources.RelationErrorArticleLabel`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:name]]
  end
end

defmodule MishkaGervaz.Test.Resources.RelationErrorArticleLabel do
  @moduledoc """
  The join between an article and a label. It refuses a label named `"foreign"`, the way a site
  refuses another site's record.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  alias MishkaGervaz.Test.Resources.{RelationErrorArticle, RelationErrorLabel}

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
  end

  relationships do
    belongs_to :article, RelationErrorArticle, allow_nil?: false, public?: true
    belongs_to :label, RelationErrorLabel, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:article_id, :label_id]]
  end

  validations do
    validate fn changeset, _context ->
               with id when not is_nil(id) <- Ash.Changeset.get_attribute(changeset, :label_id),
                    {:ok, %{name: "foreign"}} <- Ash.get(RelationErrorLabel, id) do
                 {:error, field: :label_id, message: "That label is not one this site can use."}
               else
                 _ -> :ok
               end
             end,
             before_action?: true
  end
end

defmodule MishkaGervaz.Test.Resources.RelationErrorArticle do
  @moduledoc """
  An article that picks labels by id through `:label_ids`, as a relation field of a form does.
  `:locked_create` is refused the way an authorizer refuses a write.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  alias MishkaGervaz.Test.Resources.{RelationErrorArticleLabel, RelationErrorLabel}

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
  end

  relationships do
    many_to_many :labels, RelationErrorLabel do
      through RelationErrorArticleLabel
      source_attribute_on_join_resource :article_id
      destination_attribute_on_join_resource :label_id
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title]
      argument :label_ids, {:array, :uuid}, allow_nil?: true
      change manage_relationship(:label_ids, :labels, type: :append_and_remove)
    end

    create :locked_create do
      accept [:title]

      change before_action(fn changeset, _context ->
               Ash.Changeset.add_error(
                 changeset,
                 Ash.Error.Forbidden.MustPassStrictCheck.exception([])
               )
             end)
    end
  end
end

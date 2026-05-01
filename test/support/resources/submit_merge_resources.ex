defmodule MishkaGervaz.Test.Resources.SubmitMergeDomain do
  @moduledoc """
  Test domain that defines all three submit buttons in the domain.
  Used to verify that resources inherit per-button defaults from a domain
  with a fully-populated `submit` block.
  """
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end
    end

    form do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end

      actions do
        create {:master_create, :create}
        update {:master_update, :update}
        read {:master_get, :read}
      end

      submit do
        create label: "Domain Create"
        update label: "Domain Update"
        cancel label: "Domain Cancel"
        position :bottom
      end
    end
  end

  resources do
    resource MishkaGervaz.Test.Resources.SubmitMergeNoBlock
    resource MishkaGervaz.Test.Resources.SubmitMergePartialResource
    resource MishkaGervaz.Test.Resources.SubmitMergeOverrideLabels
    resource MishkaGervaz.Test.Resources.SubmitMergeActiveFalse
    resource MishkaGervaz.Test.Resources.SubmitMergeBareButtons
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergePartialDomain do
  @moduledoc """
  Test domain with a partial submit — only `cancel` is defined.
  Resources with their own `create` and `update` should pick up `cancel`
  from this domain.
  """
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end
    end

    form do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end

      actions do
        create {:master_create, :create}
        update {:master_update, :update}
        read {:master_get, :read}
      end

      submit do
        cancel label: "Partial Cancel"
        position :bottom
      end
    end
  end

  resources do
    resource MishkaGervaz.Test.Resources.SubmitMergePartialDomainResource
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergeNoBlock do
  @moduledoc """
  Resource without a `submit` block. Should inherit the entire domain submit
  as-is (rule: resource has nothing → fall back fully to domain).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.SubmitMergeDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_merge_no_block
        route "/admin/submit-merge/no-block"
      end

      fields do
        field :title, :text
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergePartialResource do
  @moduledoc """
  Resource defining only `create` and `update`. The domain has all three
  buttons, so `cancel` should be inherited from the domain.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.SubmitMergeDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_merge_partial
        route "/admin/submit-merge/partial"
      end

      fields do
        field :title, :text
      end

      submit do
        create label: "Resource Create"
        update label: "Resource Update"
        position :top
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergeOverrideLabels do
  @moduledoc """
  Resource that overrides every domain button. Resource labels must win.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.SubmitMergeDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_merge_override
        route "/admin/submit-merge/override"
      end

      fields do
        field :title, :text
      end

      submit do
        create label: "Resource Create"
        update label: "Resource Update"
        cancel label: "Resource Cancel"
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergeActiveFalse do
  @moduledoc """
  Resource that explicitly disables a domain-inherited button via `active: false`.
  The cancel button must NOT appear even though the domain provides one.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.SubmitMergeDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_merge_active_false
        route "/admin/submit-merge/active-false"
      end

      fields do
        field :title, :text
      end

      submit do
        create label: "Resource Create"
        update label: "Resource Update"
        cancel active: false
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergeBareButtons do
  @moduledoc """
  Resource that declares buttons without explicit labels. Each button's label
  must fall back through: domain label → hard default per kind.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.SubmitMergeDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_merge_bare
        route "/admin/submit-merge/bare"
      end

      fields do
        field :title, :text
      end

      submit do
        create []
        update []
        cancel []
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitMergePartialDomainResource do
  @moduledoc """
  Resource paired with a domain that ONLY defines a cancel button.
  Resource defines its own `create` and `update`; cancel should come from the
  partial domain. No hard-coded fallback should leak in.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Resources.SubmitMergePartialDomain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_merge_partial_domain
        route "/admin/submit-merge/partial-domain"
      end

      fields do
        field :title, :text
      end

      submit do
        create label: "Resource Create"
        update label: "Resource Update"
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.RestrictedCreateForm do
  @moduledoc """
  Test resource for source-level `restricted true` — blocks all modes for non-master users.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :restricted_create_table
        route "/admin/restricted-create"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :restricted_create_form
        route "/admin/restricted-create"
      end

      source do
        master_check fn user -> user && user.role == :admin end
        restricted true

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text, required: true
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Resources.AccessPerModeForm do
  @moduledoc """
  Test resource for per-mode access control — create restricted, update has condition.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :access_per_mode_table
        route "/admin/access-per-mode"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :access_per_mode_form
        route "/admin/access-per-mode"
      end

      source do
        master_check fn user -> user && user.role == :admin end

        access :create, restricted: true
        access :update, condition: fn state -> state.master_user? or state[:can_edit?] end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text, required: true
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Resources.RestrictedFnForm do
  @moduledoc """
  Test resource for source-level `restricted fn state -> boolean end`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :restricted_fn_table
        route "/admin/restricted-fn"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :restricted_fn_form
        route "/admin/restricted-fn"
      end

      source do
        master_check fn user -> user && user.role == :admin end
        restricted fn state -> not state.master_user? end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text, required: true
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Resources.AccessGateFnForm do
  @moduledoc """
  Test resource for Style C: global gate `access fn mode, state -> boolean end`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :access_gate_fn_table
        route "/admin/access-gate-fn"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :access_gate_fn_form
        route "/admin/access-gate-fn"
      end

      source do
        master_check fn user -> user && user.role == :admin end

        access fn mode, state ->
          case mode do
            :create -> state.master_user?
            :update -> true
          end
        end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text, required: true
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Resources.AccessBareFnForm do
  @moduledoc """
  Test resource for Style B: `access :create, fn state -> boolean end` (bare fn as second arg).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :access_bare_fn_table
        route "/admin/access-bare-fn"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :access_bare_fn_form
        route "/admin/access-bare-fn"
      end

      source do
        master_check fn user -> user && user.role == :admin end

        access :create, fn state -> state.master_user? end
        access :update, fn _state -> true end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text, required: true
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Resources.ReadonlyFnForm do
  @moduledoc """
  Test resource for field `readonly` accepting a function.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :readonly_fn_table
        route "/admin/readonly-fn"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :readonly_fn_form
        route "/admin/readonly-fn"
      end

      source do
        master_check fn user -> user && user.role == :admin end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end
      end

      fields do
        field :title, :text do
          required true
          readonly fn state -> not state.master_user? end
        end

        field :content, :textarea do
          readonly true
        end

        field :status, :select do
          options [{:draft, "Draft"}, {:published, "Published"}]
          readonly false
        end
      end

      groups do
        group :main do
          fields [:title, :content, :status]

          ui do
            label "Main"
          end
        end
      end

      submit do
        create_label "Create"
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :content, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

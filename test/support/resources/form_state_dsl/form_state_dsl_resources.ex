defmodule MishkaGervaz.Test.FormStateDsl.Domain do
  @moduledoc false
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    form do
      actor_key :current_user
      master_check fn user -> user && Map.get(user, :site_id) == nil end

      actions do
        create {:master_create, :create}
        update {:master_update, :update}
        read {:master_get, :read}
      end
    end
  end

  resources do
    resource MishkaGervaz.Test.FormStateDsl.FieldOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.GroupOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.StepOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.PresentationOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.AccessOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.AllBuildersOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.WholeStateOverrideResource
    resource MishkaGervaz.Test.FormStateDsl.NoOverrideResource
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.FieldOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :field_override_form
        route "/admin/field-override"
      end

      fields do
        field :title, :text do
          required true
        end
      end

      state do
        field MishkaGervaz.Test.FormStateDsl.CustomFieldBuilder
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.GroupOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :group_override_form
        route "/admin/group-override"
      end

      fields do
        field :title, :text
      end

      groups do
        group :main do
          fields [:title]

          ui do
            label "Main"
          end
        end
      end

      state do
        group MishkaGervaz.Test.FormStateDsl.CustomGroupBuilder
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.StepOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :step_override_form
        route "/admin/step-override"
      end

      fields do
        field :title, :text
        field :body, :textarea
      end

      groups do
        group :one do
          fields [:title]

          ui do
            label "One"
          end
        end

        group :two do
          fields [:body]

          ui do
            label "Two"
          end
        end
      end

      layout do
        mode :wizard

        step :first do
          groups [:one]

          ui do
            label "First"
          end
        end

        step :second do
          groups [:two]

          ui do
            label "Second"
          end
        end
      end

      state do
        step MishkaGervaz.Test.FormStateDsl.CustomStepBuilder
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
    attribute :body, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.PresentationOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :presentation_override_form
        route "/admin/presentation-override"
      end

      fields do
        field :title, :text
      end

      state do
        presentation MishkaGervaz.Test.FormStateDsl.CustomPresentation
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.AccessOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :access_override_form
        route "/admin/access-override"
      end

      fields do
        field :title, :text
      end

      state do
        access MishkaGervaz.Test.FormStateDsl.CustomAccess
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.AllBuildersOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :all_builders_override_form
        route "/admin/all-builders-override"
      end

      fields do
        field :title, :text
      end

      groups do
        group :main do
          fields [:title]

          ui do
            label "Main"
          end
        end
      end

      state do
        field MishkaGervaz.Test.FormStateDsl.CustomFieldBuilder
        group MishkaGervaz.Test.FormStateDsl.CustomGroupBuilder
        presentation MishkaGervaz.Test.FormStateDsl.CustomPresentation
        access MishkaGervaz.Test.FormStateDsl.CustomAccess
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.WholeStateOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :whole_state_override_form
        route "/admin/whole-state-override"
      end

      fields do
        field :title, :text
      end

      state do
        module MishkaGervaz.Test.FormStateDsl.CustomWholeState
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.NoOverrideResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.FormStateDsl.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :no_override_form
        route "/admin/no-override"
      end

      fields do
        field :title, :text
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :master_create
    update :master_update
    read :master_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end

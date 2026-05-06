defmodule MishkaGervaz.Test.FormDataLoaderDsl do
  @moduledoc """
  Test resources and modules for the form `data_loader` DSL section.
  Mirrors the table-side data_loader DSL fixtures.
  """

  defmodule CustomRecordLoader do
    @moduledoc false
    use MishkaGervaz.Form.Web.DataLoader.RecordLoader
  end

  defmodule CustomTenantResolver do
    @moduledoc false
    use MishkaGervaz.Form.Web.DataLoader.TenantResolver

    def get_tenant(state) do
      Process.put(:custom_form_tenant_resolver_called, true)
      super(state)
    end
  end

  defmodule CustomRelationLoader do
    @moduledoc false
    use MishkaGervaz.Form.Web.DataLoader.RelationLoader
  end

  defmodule CustomHookRunner do
    @moduledoc false
    use MishkaGervaz.Form.Web.DataLoader.HookRunner
  end

  defmodule CustomDataLoaderModule do
    @moduledoc false
    use MishkaGervaz.Form.Web.DataLoader
  end

  defmodule TestDomain do
    @moduledoc false
    use Ash.Domain, extensions: [MishkaGervaz.Domain], validate_config_inclusion?: false

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
      resource MishkaGervaz.Test.FormDataLoaderDsl.RecordOverrideResource
      resource MishkaGervaz.Test.FormDataLoaderDsl.TenantOverrideResource
      resource MishkaGervaz.Test.FormDataLoaderDsl.RelationOverrideResource
      resource MishkaGervaz.Test.FormDataLoaderDsl.HooksOverrideResource
      resource MishkaGervaz.Test.FormDataLoaderDsl.AllSubBuildersResource
      resource MishkaGervaz.Test.FormDataLoaderDsl.WholeModuleResource
      resource MishkaGervaz.Test.FormDataLoaderDsl.NoOverrideResource
    end
  end

  defmodule RecordOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_record
          route "/admin/form-dl-record"
        end

        fields do
          field :title, :text
        end

        data_loader do
          record MishkaGervaz.Test.FormDataLoaderDsl.CustomRecordLoader
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

  defmodule TenantOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_tenant
          route "/admin/form-dl-tenant"
        end

        fields do
          field :title, :text
        end

        data_loader do
          tenant MishkaGervaz.Test.FormDataLoaderDsl.CustomTenantResolver
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

  defmodule RelationOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_relation
          route "/admin/form-dl-relation"
        end

        fields do
          field :title, :text
        end

        data_loader do
          relation MishkaGervaz.Test.FormDataLoaderDsl.CustomRelationLoader
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

  defmodule HooksOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_hooks
          route "/admin/form-dl-hooks"
        end

        fields do
          field :title, :text
        end

        data_loader do
          hooks MishkaGervaz.Test.FormDataLoaderDsl.CustomHookRunner
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

  defmodule AllSubBuildersResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_all
          route "/admin/form-dl-all"
        end

        fields do
          field :title, :text
        end

        data_loader do
          record MishkaGervaz.Test.FormDataLoaderDsl.CustomRecordLoader
          tenant MishkaGervaz.Test.FormDataLoaderDsl.CustomTenantResolver
          relation MishkaGervaz.Test.FormDataLoaderDsl.CustomRelationLoader
          hooks MishkaGervaz.Test.FormDataLoaderDsl.CustomHookRunner
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

  defmodule WholeModuleResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_whole_module
          route "/admin/form-dl-whole-module"
        end

        fields do
          field :title, :text
        end

        data_loader MishkaGervaz.Test.FormDataLoaderDsl.CustomDataLoaderModule
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

  defmodule NoOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormDataLoaderDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_dl_no_override
          route "/admin/form-dl-no-override"
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
end

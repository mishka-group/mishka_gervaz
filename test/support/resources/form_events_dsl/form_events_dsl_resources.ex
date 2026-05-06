defmodule MishkaGervaz.Test.FormEventsDsl do
  @moduledoc """
  Test resources and handler modules for the form `events` DSL section.
  Mirrors the table-side EventsDsl fixtures.
  """

  defmodule CustomSanitizationHandler do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.SanitizationHandler

    def sanitize_params(params) do
      Process.put(:custom_form_sanitization_called, true)
      super(params)
    end
  end

  defmodule CustomValidationHandler do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.ValidationHandler
  end

  defmodule CustomSubmitHandler do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.SubmitHandler
  end

  defmodule CustomStepHandler do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.StepHandler
  end

  defmodule CustomUploadHandler do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.UploadHandler
  end

  defmodule CustomRelationHandler do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.RelationHandler

    def handle(action, params, state, socket) do
      Process.put(:custom_form_relation_called, true)
      Process.put(:custom_form_relation_action, action)
      super(action, params, state, socket)
    end
  end

  defmodule CustomHookRunner do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events.HookRunner

    def run_hook(hooks, hook_name, args) do
      Process.put(:custom_form_hook_runner_called, true)
      Process.put(:custom_form_hook_name, hook_name)
      super(hooks, hook_name, args)
    end
  end

  defmodule CustomEventsModule do
    @moduledoc false
    use MishkaGervaz.Form.Web.Events
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
      resource MishkaGervaz.Test.FormEventsDsl.SanitizationOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.ValidationOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.SubmitOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.StepOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.UploadOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.RelationOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.HooksOverrideResource
      resource MishkaGervaz.Test.FormEventsDsl.AllHandlersResource
      resource MishkaGervaz.Test.FormEventsDsl.WholeModuleResource
      resource MishkaGervaz.Test.FormEventsDsl.NoOverrideResource
    end
  end

  defmodule SanitizationOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_sanitization
          route "/admin/form-events-sanitization"
        end

        fields do
          field :title, :text
        end

        events do
          sanitization MishkaGervaz.Test.FormEventsDsl.CustomSanitizationHandler
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

  defmodule ValidationOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_validation
          route "/admin/form-events-validation"
        end

        fields do
          field :title, :text
        end

        events do
          validation MishkaGervaz.Test.FormEventsDsl.CustomValidationHandler
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

  defmodule SubmitOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_submit
          route "/admin/form-events-submit"
        end

        fields do
          field :title, :text
        end

        events do
          submit MishkaGervaz.Test.FormEventsDsl.CustomSubmitHandler
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

  defmodule StepOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_step
          route "/admin/form-events-step"
        end

        fields do
          field :title, :text
        end

        events do
          step MishkaGervaz.Test.FormEventsDsl.CustomStepHandler
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

  defmodule UploadOverrideResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_upload
          route "/admin/form-events-upload"
        end

        fields do
          field :title, :text
        end

        events do
          upload MishkaGervaz.Test.FormEventsDsl.CustomUploadHandler
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
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_relation
          route "/admin/form-events-relation"
        end

        fields do
          field :title, :text
        end

        events do
          relation MishkaGervaz.Test.FormEventsDsl.CustomRelationHandler
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
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_hooks
          route "/admin/form-events-hooks"
        end

        fields do
          field :title, :text
        end

        events do
          hooks MishkaGervaz.Test.FormEventsDsl.CustomHookRunner
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

  defmodule AllHandlersResource do
    @moduledoc false
    use Ash.Resource,
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_all
          route "/admin/form-events-all"
        end

        fields do
          field :title, :text
        end

        events do
          sanitization MishkaGervaz.Test.FormEventsDsl.CustomSanitizationHandler
          validation MishkaGervaz.Test.FormEventsDsl.CustomValidationHandler
          submit MishkaGervaz.Test.FormEventsDsl.CustomSubmitHandler
          step MishkaGervaz.Test.FormEventsDsl.CustomStepHandler
          upload MishkaGervaz.Test.FormEventsDsl.CustomUploadHandler
          relation MishkaGervaz.Test.FormEventsDsl.CustomRelationHandler
          hooks MishkaGervaz.Test.FormEventsDsl.CustomHookRunner
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
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_whole_module
          route "/admin/form-events-whole-module"
        end

        fields do
          field :title, :text
        end

        events MishkaGervaz.Test.FormEventsDsl.CustomEventsModule
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
      domain: MishkaGervaz.Test.FormEventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      form do
        identity do
          name :form_events_no_override
          route "/admin/form-events-no-override"
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

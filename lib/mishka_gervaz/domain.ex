defmodule MishkaGervaz.Domain do
  @moduledoc """
  Ash Domain extension for MishkaGervaz shared table and form configuration.

  Add this extension to your Ash domain to set default table and form
  configuration that will be inherited by all resources using
  `MishkaGervaz.Resource`:

      defmodule MyApp.CMS do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain]

        mishka_gervaz do
          table do
            actor_key :current_user
            ui_adapter MishkaGervaz.UIAdapters.Tailwind

            pagination do
              type :load_more
              page_size 20
              page_size_options [20, 50, 100]
            end

            realtime do
              pubsub MyApp.PubSub
            end

            actions do
              read {:master_read, :read}
              get {:master_get, :read}
              destroy {:master_destroy, :destroy}
            end

            archive do
              read_action {:master_archived, :archived}
              get_action {:master_get_archived, :get_archived}
              restore_action {:master_unarchive, :unarchive}
              destroy_action {:master_permanent_destroy, :permanent_destroy}
            end
          end

          form do
            actions do
              create {:master_create, :create}
              update {:master_update, :update}
              read {:master_get, :read}
            end

            submit do
              create label: "Create"
              update label: "Save Changes"
              cancel label: "Cancel"
              position :bottom
            end
          end
        end

        resources do
          resource MyApp.CMS.BlogPost
          resource MyApp.CMS.Comment
        end
      end

  ## Sections

  - `table` - Table configuration inherited by all resources in this domain.
    See `MishkaGervaz.Table.Dsl.Defaults`.
    - `ui_adapter` / `ui_adapter_opts` - Default UI adapter for tables
    - `actor_key` - Key to get the actor from socket assigns
    - `master_check` - Function to check if user is master
    - `actions` - Default `read` / `get` / `destroy` action mapping
    - `archive` - Default archive action mapping
      (`read_action`, `get_action`, `restore_action`, `destroy_action`)
    - `pagination` - Default pagination settings
    - `realtime` - Default realtime/PubSub settings
    - `theme` - Default table theme
    - `refresh` - Default auto-refresh settings
    - `url_sync` - Default URL synchronization settings
  - `form` - Form configuration inherited by all resources in this domain.
    See `MishkaGervaz.Form.Dsl.DomainDefaults`.
    - `ui_adapter` / `ui_adapter_opts` - Default UI adapter for forms
    - `actor_key` - Key to get the actor from socket assigns
    - `master_check` - Function to check if user is master
    - `template` - Default form template module
    - `features` - Default form features (`:all` or a subset)
    - `actions` - Default form action mapping (create/update/read)
    - `theme` - Default form theme
    - `layout` - Default form layout (navigation, persistence, columns, responsive)
    - `submit` - Default submit/update/cancel button labels
  - `navigation` - Admin navigation structure.
    See `MishkaGervaz.Table.Dsl.Navigation`.
    - `menu_group` - Group resources. See `MishkaGervaz.Table.Entities.MenuGroup`.

  ## Introspection

  Use `MishkaGervaz.Domain.Info.Table` and `MishkaGervaz.Domain.Info.Form` to
  introspect the configuration:

      table_defaults = MishkaGervaz.Domain.Info.Table.config(MyApp.CMS)
      form_defaults  = MishkaGervaz.Domain.Info.Form.config(MyApp.CMS)
  """

  @mishka_gervaz %Spark.Dsl.Section{
    name: :mishka_gervaz,
    describe: "MishkaGervaz domain configuration for shared table and form defaults.",
    sections: [
      MishkaGervaz.Table.Dsl.Defaults.section(),
      MishkaGervaz.Form.Dsl.DomainDefaults.section(),
      MishkaGervaz.Table.Dsl.Navigation.section()
    ]
  }

  @transformers [
    MishkaGervaz.Table.Transformers.BuildDomainConfig,
    MishkaGervaz.Form.Transformers.BuildDomainConfig
  ]

  @verifiers [
    MishkaGervaz.Table.Verifiers.ValidateDomainDefaults
  ]

  use Spark.Dsl.Extension,
    sections: [@mishka_gervaz],
    transformers: @transformers,
    verifiers: @verifiers
end

defmodule MishkaGervaz.Domain do
  @moduledoc """
  Ash Domain extension for MishkaGervaz shared table and form configuration.

  Add this extension to your Ash domain to set default table configuration
  that will be inherited by all resources using `MishkaGervaz.Resource`:

      defmodule MyApp.CMS do
        use Ash.Domain,
          extensions: [MishkaGervaz.Domain]

        mishka_gervaz do
          table do
            ui_adapter MishkaGervaz.Table.UIAdapters.Tailwind
            actor_key :current_user
            master_check &MyApp.Accounts.master_user?/1

            pagination page_size: 25, type: :infinite

            theme do
              header_class "bg-gray-100"
            end
          end

          navigation do
            menu_group :content do
              label "Content"
              icon "document"
              resources [MyApp.CMS.BlogPost, MyApp.CMS.Comment]
            end
          end
        end

        resources do
          resource MyApp.CMS.BlogPost
          resource MyApp.CMS.Comment
        end
      end

  ## Sections

  - `table` - Table configuration. See `MishkaGervaz.Table.Dsl.Defaults`
    - `ui_adapter` - UI adapter module
    - `actor_key` - Key to get actor from socket assigns
    - `master_check` - Function to check if user is master
    - `actions` - Action mapping
    - `pagination` - Pagination settings
    - `realtime` - Realtime settings
    - `theme` - Theme settings
    - `refresh` - Auto-refresh settings
    - `url_sync` - URL synchronization settings
  - `navigation` - Admin navigation structure. See `MishkaGervaz.Table.Dsl.Navigation`
    - `menu_group` - Group resources. See `MishkaGervaz.Table.Entities.MenuGroup`

  ## Introspection

  Use `MishkaGervaz.Domain.Info.Table` to introspect the configuration:

      config = MishkaGervaz.Domain.Info.Table.config(MyApp.CMS)
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

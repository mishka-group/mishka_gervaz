defmodule MishkaGervaz.Test.Domain do
  @moduledoc """
  Test domain for MishkaGervaz tests.
  """
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      # Required: actor_key and master_check (can be in domain or resource)
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end

      pagination type: :numbered, page_size: 20

      ui_adapter MishkaGervaz.UIAdapters.Tailwind

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
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end
      template MishkaGervaz.Form.Templates.Standard
      features :all
      ui_adapter MishkaGervaz.UIAdapters.Tailwind

      actions do
        create {:master_create, :create}
        update {:master_update, :update}
        read {:master_get, :read}
      end

      layout do
        responsive true
      end

      submit do
        create label: "Save"
        update label: "Save Changes"
        cancel label: "Cancel"
        position :bottom
      end
    end

    navigation do
      menu_group :content do
        label "Content"
        icon "hero-document-text"
      end

      menu_group :users do
        label "Users"
        icon "hero-users"
      end
    end
  end

  resources do
    resource MishkaGervaz.Test.Resources.Post
    resource MishkaGervaz.Test.Resources.User
    resource MishkaGervaz.Test.Resources.Comment
    resource MishkaGervaz.Test.Resources.MinimalResource
    resource MishkaGervaz.Test.Resources.AutoColumnsResource
    resource MishkaGervaz.Test.Resources.ArchivableResource
    resource MishkaGervaz.Test.Resources.FormPost
    resource MishkaGervaz.Test.Resources.NestedForm
    resource MishkaGervaz.Test.Resources.NestedDslForm
    resource MishkaGervaz.Test.Resources.SubmitOptionsForm
    resource MishkaGervaz.Test.Resources.NoButtonsForm
    resource MishkaGervaz.Test.Resources.ArchiveMergeNoExt
    resource MishkaGervaz.Test.Resources.ArchiveMergeInheritDomain
    resource MishkaGervaz.Test.Resources.ArchiveMergeEnabledFalse
    resource MishkaGervaz.Test.Resources.ArchiveMergePartial
    resource MishkaGervaz.Test.Resources.ArchiveMergeAtomAction
    allow_unregistered? true
  end
end

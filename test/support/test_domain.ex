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
    end

    form do
      actor_key :current_user
      master_check fn user -> user && user.role == :admin end
      template MishkaGervaz.Form.Templates.Standard
      features :all
      ui_adapter MishkaGervaz.UIAdapters.Tailwind

      layout do
        responsive true
      end

      submit do
        create_label "Save"
        update_label "Save Changes"
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
    allow_unregistered? true
  end
end

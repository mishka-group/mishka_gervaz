defmodule MishkaGervaz.Test.Resources.FormPost do
  @moduledoc """
  Test resource for the form DSL — standard form with full DSL coverage.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :form_post_table
        route "/admin/posts"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :form_post
        route "/admin/posts"
      end

      source do
        actor_key :current_user
        master_check fn user -> user && user.role == :admin end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end

        preload do
          always [:user]
          master [:comments]
        end
      end

      fields do
        field :title, :text do
          required(true)
          position :first

          ui do
            label "Post Title"
            placeholder "Enter title..."
            description "Main title"
            icon "hero-document-text"
            class "font-bold"
            span(2)
            debounce 300
          end
        end

        field :content, :textarea do
          ui do
            label "Content"
            rows(10)
          end
        end

        field :status, :select do
          required(true)
          default :draft
          options [{:draft, "Draft"}, {:published, "Published"}, {:archived, "Archived"}]
          include_nil "-- Select --"

          ui do
            label "Status"
          end
        end

        field :priority, :number do
          min 0
          max 100
          default 0

          ui do
            label "Priority"
            step 1
          end
        end

        field :featured, :toggle do
          default false

          ui do
            label "Featured"
          end
        end

        field :metadata, :json do
          ui do
            label "Metadata"
            rows(5)
          end
        end
      end

      groups do
        group :general do
          fields [:title, :content, :status]
          position :first

          ui do
            label "General"
            icon "hero-pencil"
            description "Core fields"
            class "border p-4"
            header_class "text-lg font-bold"
            extra %{custom: true}
          end
        end

        group :settings do
          fields [:priority, :featured, :metadata]
          collapsible true
          collapsed(true)

          ui do
            label "Settings"
          end
        end
      end

      layout do
        columns 2
        mode :standard
        responsive(true)
      end

      uploads do
        upload :cover do
          accept "image/*"
          max_entries(1)
          max_file_size(5_000_000)
          show_preview(true)
          auto_upload(true)
          dropzone_text("Drop image here")

          ui do
            label "Cover Image"
            icon "hero-photo"
            class "border-dashed"
            preview_class("w-32 h-32")
            extra %{rounded: true}
          end
        end
      end

      presentation do
        features :all

        theme do
          form_class("max-w-4xl")
          field_class("rounded-md")
          label_class("text-sm font-medium")
          error_class("text-red-600")
          extra %{variant: :default}
        end
      end

      hooks do
        on_init(fn form, _state -> form end)
        before_save(fn params, _state -> params end)
        after_save(fn _result, state -> state end)
        on_error fn _form, state -> state end
        on_cancel(fn state -> state end)
        on_validate(fn params, _state -> params end)
        on_change(fn _field, _value, state -> state end)
        transform_params(fn params -> params end)
        transform_errors(fn _changeset, errors -> errors end)
      end

      submit do
        create_label("Create Post")
        update_label("Save Post")
        cancel_label("Discard")
        show_cancel(true)
        position :bottom

        ui do
          submit_class("bg-blue-600 text-white")
          cancel_class("bg-gray-200")
          wrapper_class("flex gap-4")
          extra %{rounded: true}
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      prepare build(sort: [inserted_at: :desc])
    end

    read :tenant_read do
      prepare build(sort: [inserted_at: :desc])
    end
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

    attribute :priority, :integer do
      default 0
      public? true
    end

    attribute :featured, :boolean do
      default false
      public? true
    end

    attribute :metadata, :map do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, MishkaGervaz.Test.Resources.User do
      allow_nil? false
      public? true
    end
  end
end

defmodule MishkaGervaz.Test.Resources.WizardForm do
  @moduledoc """
  Test resource for the form DSL — wizard mode with steps.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :wizard_form_table
        route "/admin/wizard"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :wizard_form
        route "/admin/wizard"
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
        field :title, :text, required: true
        field :content, :textarea

        field :status, :select do
          options [{:draft, "Draft"}, {:published, "Published"}]
        end

        field :priority, :number, min: 0, max: 100
        field :featured, :toggle, default: false
      end

      groups do
        group :basic do
          fields [:title, :content]
        end

        group :meta do
          fields [:status, :priority]
        end

        group :flags do
          fields [:featured]
        end
      end

      layout do
        mode :wizard
        columns 2
        navigation(:sequential)
        persistence(:ets)

        step :details do
          groups [:basic]
          action :validate_details

          on_enter(fn state -> state end)
          before_leave(fn state -> state end)
          after_leave(fn state -> state end)

          ui do
            label "Details"
            icon "hero-information-circle"
            description "Enter basic info"
            class "step-details"
            header_class "font-bold"
            extra %{order: 1}
          end
        end

        step :settings do
          groups [:meta]

          ui do
            label "Settings"
            icon "hero-cog"
          end
        end

        step :review do
          groups [:flags]
          summary(true)

          ui do
            label "Review"
            icon "hero-check-circle"
          end
        end
      end

      submit do
        create_label("Finish")
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      prepare build(sort: [inserted_at: :desc])
    end

    read :tenant_read do
      prepare build(sort: [inserted_at: :desc])
    end
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

    attribute :priority, :integer do
      default 0
      public? true
    end

    attribute :featured, :boolean do
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, MishkaGervaz.Test.Resources.User do
      allow_nil? false
      public? true
    end
  end
end

defmodule MishkaGervaz.Test.Resources.TabsForm do
  @moduledoc """
  Test resource for the form DSL — tabs mode with free navigation.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :tabs_form_table
        route "/admin/tabs"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :tabs_form
        route "/admin/tabs"
      end

      source do
        master_check fn user -> user && user.role == :admin end

        actions do
          create :create
          update :update
          read :read
        end
      end

      fields do
        field :title, :text, required: true
        field :content, :textarea

        field :status, :select do
          options [{:draft, "Draft"}, {:published, "Published"}]
        end

        field :priority, :number
        field :featured, :toggle
      end

      groups do
        group :content_group do
          fields [:title, :content]
        end

        group :settings_group do
          fields [:status, :priority, :featured]
        end
      end

      layout do
        mode :tabs
        columns 1
        navigation(:free)
        persistence(:client_token)

        step :content_tab do
          groups [:content_group]

          ui do
            label "Content"
            icon "hero-document"
          end
        end

        step :settings_tab do
          groups [:settings_group]
          visible fn _assigns -> true end

          ui do
            label "Settings"
          end
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      prepare build(sort: [inserted_at: :desc])
    end

    read :tenant_read do
      prepare build(sort: [inserted_at: :desc])
    end
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

    attribute :priority, :integer do
      default 0
      public? true
    end

    attribute :featured, :boolean do
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, MishkaGervaz.Test.Resources.User do
      allow_nil? false
      public? true
    end
  end
end

defmodule MishkaGervaz.Test.Resources.MinimalForm do
  @moduledoc """
  Test resource for the form DSL — bare minimum (no groups, steps, hooks, or uploads).
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :minimal_form_table
        route "/admin/minimal-form"
      end

      columns do
        column :title
      end
    end

    form do
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

defmodule MishkaGervaz.Test.Resources.NoMasterCheckForm do
  @moduledoc """
  Test resource for the form DSL — no explicit master_check, tests default fallback.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :no_master_check_form_table
        route "/admin/no-master-check-form"
      end

      columns do
        column :title
      end
    end

    form do
      source do
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

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

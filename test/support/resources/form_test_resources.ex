defmodule MishkaGervaz.Test.Resources.TestEmbed do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :value, :string, public?: true
    attribute :count, :integer, public?: true
    attribute :active, :boolean, public?: true
  end
end

defmodule MishkaGervaz.Test.Resources.SingleEmbed do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :street, :string, allow_nil?: false, public?: true
    attribute :city, :string, allow_nil?: false, public?: true
    attribute :zip, :string, public?: true
  end
end

defmodule MishkaGervaz.Test.Resources.NestedForm do
  @moduledoc """
  Test resource for nested/embedded form fields — auto-infer + map-based nested_fields.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :nested_form_table
        route "/admin/nested"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :nested_form
        route "/admin/nested"
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
        end

        # Auto-infer all sub-fields from TestEmbed, add_label in ui do
        field :items, :nested do
          ui do
            label "Items"
            add_label "+ Add Item"
            remove_label "Remove"
          end
        end

        # Auto-infer from SingleEmbed (single, not array)
        field :address do
        end

        # Explicit map-based nested_fields (backward compat)
        field :tags, :nested do
          nested_fields [
            %{name: :name, type: :text, label: "Tag Name"},
            %{name: :value, type: :textarea, label: "Tag Value"}
          ]

          add_label "+ Add Tag"
        end
      end

      groups do
        group :main do
          fields [:title, :items, :address, :tags]

          ui do
            label "Main"
          end
        end
      end

      submit do
        create label: "Create"
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

    attribute :items, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    attribute :address, MishkaGervaz.Test.Resources.SingleEmbed do
      public? true
    end

    attribute :tags, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.NestedDslForm do
  @moduledoc """
  Test resource for nested_field DSL entity — explicit overrides with ui do blocks.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :nested_dsl_form_table
        route "/admin/nested-dsl"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :nested_dsl_form
        route "/admin/nested-dsl"
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

        # nested_field DSL entities with overrides
        field :items, :nested do
          ui do
            label "Custom Items"
            add_label "+ Add Custom Item"
            remove_label "Remove Item"
          end

          # Override :name — custom label and placeholder
          nested_field :name do
            ui do
              label "Item Name"
              placeholder "e.g. Widget"
            end
          end

          # Override :count — type auto-detected as :number
          nested_field :count do
            required true

            ui do
              label "Quantity"
              placeholder "0"
            end
          end

          # Override :active — hidden from form
          nested_field :active do
            visible false
          end

          # :value not listed — auto-inferred from embed
        end

        # Single embed with nested_field overrides
        field :address, :nested do
          ui do
            label "Address"
          end

          nested_field :street do
            ui do
              label "Street Address"
              placeholder "123 Main St"
              span 2
            end
          end

          nested_field :zip do
            ui do
              placeholder "e.g. 90210"
            end
          end

          # :city not listed — auto-inferred
        end

        # nested_field with type override (text -> textarea)
        field :notes, :nested do
          ui do
            label "Notes"
            add_label "+ Add Note"
          end

          nested_field :name, :text do
            required true

            ui do
              label "Note Title"
              placeholder "Title..."
            end
          end

          nested_field :value, :textarea do
            ui do
              label "Note Content"
              placeholder "Write your note..."
              rows 6
              class "font-mono text-sm"
            end
          end
        end
      end

      groups do
        group :main do
          fields [:title, :items, :address, :notes]

          ui do
            label "Main"
          end
        end
      end

      submit do
        create label: "Create"
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

    attribute :title, :string, allow_nil?: false, public?: true

    attribute :items, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    attribute :address, MishkaGervaz.Test.Resources.SingleEmbed, public?: true

    attribute :notes, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

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
          required true
          position :first

          ui do
            label "Post Title"
            placeholder "Enter title..."
            description "Main title"
            icon "hero-document-text"
            class "font-bold"
            span 2
            debounce 300
          end
        end

        field :content, :textarea do
          ui do
            label "Content"
            rows 10
          end
        end

        field :status, :select do
          required true
          default :draft
          options [{:draft, "Draft"}, {:published, "Published"}, {:archived, "Archived"}]
          include_nil "-- Select --"

          ui do
            label "Status"
          end
        end

        field :language, :combobox do
          options [{"English", "en"}, {"Persian", "fa"}, {"Arabic", "ar"}]

          ui do
            label "Language"
            placeholder "Type or select language..."
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
            rows 5
          end
        end

        field :user_id, :relation do
          load_action {:master_read, :tenant_read}
          mode :search
          display_field :email
          search_field :email

          ui do
            label "User"
          end
        end
      end

      groups do
        group :general do
          fields [:title, :content, :status, :language]
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
          fields [:priority, :featured, :metadata, :user_id]
          collapsible true
          collapsed true

          ui do
            label "Settings"
          end
        end
      end

      layout do
        columns 2
        mode :standard
        responsive true
      end

      uploads do
        upload :cover do
          accept "image/*"
          max_entries 1
          max_file_size 5_000_000
          show_preview true
          auto_upload true
          dropzone_text "Drop image here"

          ui do
            label "Cover Image"
            icon "hero-photo"
            class "border-dashed"
            preview_class "w-32 h-32"
            extra %{rounded: true}
          end
        end
      end

      presentation do
        features :all

        theme do
          form_class "max-w-4xl"
          field_class "rounded-md"
          label_class "text-sm font-medium"
          error_class "text-red-600"
          extra %{variant: :default}
        end
      end

      hooks do
        on_init fn form, _state -> form end
        before_save fn params, _state -> params end
        after_save fn _result, state -> state end
        on_error fn _form, state -> state end
        on_cancel fn state -> state end
        on_validate fn params, _state -> params end
        on_change fn _field, _value, state -> state end
        transform_params fn params -> params end
        transform_errors fn _changeset, errors -> errors end

        js do
          on_init fn -> Phoenix.LiveView.JS.dispatch("form:init") end
          after_save fn _id -> Phoenix.LiveView.JS.dispatch("form:saved") end
          on_cancel fn _id -> Phoenix.LiveView.JS.dispatch("form:cancelled") end
          on_error fn _id -> Phoenix.LiveView.JS.dispatch("form:error") end
        end
      end

      submit do
        create label: "Create Post"
        update label: "Save Post"
        cancel label: "Discard"
        position :bottom

        ui do
          submit_class "bg-blue-600 text-white"
          cancel_class "bg-gray-200"
          wrapper_class "flex gap-4"
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

    attribute :language, :string do
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
        navigation :sequential
        persistence :ets

        step :details do
          groups [:basic]
          action :validate_details

          on_enter fn state -> state end
          before_leave fn state -> state end
          after_leave fn state -> state end

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
          summary true

          ui do
            label "Review"
            icon "hero-check-circle"
          end
        end
      end

      submit do
        create label: "Finish"
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
        navigation :free
        persistence :client_token

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

defmodule MishkaGervaz.Test.Resources.AutoFieldsForm do
  @moduledoc """
  Test resource for auto_fields DSL — diverse attributes for auto-discovery testing.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :auto_fields_form_table
        route "/admin/auto-fields"
      end

      columns do
        column :name
      end
    end

    form do
      identity do
        name :auto_fields_form
        route "/admin/auto-fields"
      end

      fields do
        field :name, :text, required: true

        auto_fields do
          except [:id, :internal_only]
          position :end

          defaults required: false, visible: true, readonly: false

          ui_defaults boolean_widget: :checkbox,
                      textarea_threshold: 255,
                      number_step: 1,
                      select_prompt: "Select...",
                      datetime_format: :medium

          override :age, type: :range, required: true

          override :bio do
            ui do
              label "Biography"
              rows 8
            end
          end
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :age, :integer do
      public? true
    end

    attribute :active, :boolean do
      default false
      public? true
    end

    attribute :bio, :string do
      public? true
    end

    attribute :settings, :map do
      public? true
    end

    attribute :birthday, :date do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      public? true
    end

    attribute :internal_only, :string do
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.StringListForm do
  @moduledoc """
  Test resource for string_list field type and auto-type detection.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :string_list_form_table
        route "/admin/string-list"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :string_list_form
        route "/admin/string-list"
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

        field :tags, :string_list do
          add_label "+ Add Tag"
          remove_label "Remove"

          ui do
            label "Tags"
            placeholder "Enter a tag"
          end
        end

        field :origins do
          add_label fn -> "Add Origin" end

          ui do
            label "Origins"
            placeholder "https://example.com"
          end
        end
      end

      groups do
        group :main do
          fields [:title, :tags, :origins]

          ui do
            label "Main"
          end
        end
      end

      submit do
        create label: "Create"
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

    attribute :tags, {:array, :string} do
      default []
      public? true
    end

    attribute :origins, {:array, :string} do
      default []
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.UploadFieldForm do
  @moduledoc """
  Test resource for the upload field type — inline upload positioning.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :upload_field_form_table
        route "/admin/upload-field"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :upload_field_form
        route "/admin/upload-field"
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
        field :cover, :upload
        field :content, :textarea
      end

      groups do
        group :main do
          fields [:title, :cover, :content]

          ui do
            label "Main"
          end
        end
      end

      uploads do
        upload :cover do
          accept "image/*"
          max_entries 1
          max_file_size 5_000_000
        end
      end

      submit do
        create label: "Create"
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

    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.Resources.ConstrainedMapForm do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :constrained_map_form_table
        route "/admin/constrained-map"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :constrained_map_form
        route "/admin/constrained-map"
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

        field :slots, :nested do
          ui do
            label "Slots"
            add_label "+ Add Slot"
            remove_label "Remove"
          end

          nested_field :name do
            required true

            ui do
              label "Name"
              placeholder "Slot name"
            end
          end

          nested_field :opts, :json do
            ui do
              label "Options"
              placeholder ~s({"key": "value"})
            end
          end
        end
      end

      groups do
        group :main do
          fields [:title, :slots]

          ui do
            label "Main"
          end
        end
      end

      submit do
        create label: "Create"
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

    attribute :slots, {:array, :map} do
      default []
      public? true

      constraints items: [
                    fields: [
                      name: [
                        type: :string,
                        allow_nil?: false
                      ],
                      opts: [
                        type: :map,
                        allow_nil?: true
                      ]
                    ]
                  ]
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.AutoNestedFieldsForm do
  @moduledoc """
  Test resource for auto_fields option — override specific sub-fields
  while keeping all auto-detected ones.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :auto_fields_table
        route "/admin/auto-nested"
      end

      columns do
        column :title
      end
    end

    form do
      identity do
        name :auto_fields_form
        route "/admin/auto-nested"
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

        # auto_fields true: override :name only, keep :value, :count, :active
        field :items, :nested do
          auto_fields(true)

          ui do
            label "Items"
            add_label "+ Add Item"
          end

          nested_field :name do
            ui do
              label "Custom Item Name"
              placeholder "Enter name..."
            end
          end
        end

        # auto_fields true on single embed: override :street only, keep :city and :zip
        field :address, :nested do
          auto_fields(true)

          ui do
            label "Address"
          end

          nested_field :street, :textarea do
            ui do
              label "Full Street Address"
              placeholder "123 Main St, Apt 4"
              rows 3
              span 2
            end
          end
        end

        # auto_fields true with position overrides
        field :positioned_items, :nested do
          auto_fields(true)

          ui do
            label "Positioned Items"
          end

          nested_field :name do
            position :last

            ui do
              label "Name (Last)"
            end
          end

          nested_field :active do
            position :first

            ui do
              label "Active (First)"
            end
          end
        end

        # auto_fields true with integer position
        field :integer_pos_items, :nested do
          auto_fields(true)

          nested_field :count do
            position 0

            ui do
              label "Count (pos 0)"
            end
          end

          nested_field :active do
            position 1

            ui do
              label "Active (pos 1)"
            end
          end
        end

        # auto_fields true with {:before, :field} and {:after, :field}
        field :relative_pos_items, :nested do
          auto_fields(true)

          nested_field :active do
            position {:before, :value}

            ui do
              label "Active (before value)"
            end
          end

          nested_field :count do
            position {:after, :name}

            ui do
              label "Count (after name)"
            end
          end
        end

        # auto_fields false (default): override :name only, others excluded
        field :notes, :nested do
          ui do
            label "Notes"
            add_label "+ Add Note"
          end

          nested_field :name do
            ui do
              label "Note Title"
            end
          end
        end
      end

      groups do
        group :main do
          fields [
            :title,
            :items,
            :address,
            :positioned_items,
            :integer_pos_items,
            :relative_pos_items,
            :notes
          ]

          ui do
            label "Main"
          end
        end
      end

      submit do
        create label: "Create"
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

    attribute :title, :string, allow_nil?: false, public?: true

    attribute :items, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    attribute :address, MishkaGervaz.Test.Resources.SingleEmbed, public?: true

    attribute :positioned_items, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    attribute :integer_pos_items, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    attribute :relative_pos_items, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    attribute :notes, {:array, MishkaGervaz.Test.Resources.TestEmbed} do
      default []
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

defmodule MishkaGervaz.Test.Resources.SubmitOptionsForm do
  @moduledoc """
  Test resource for per-button submit options: disabled, restricted, visible.
  Uses both inline and block syntax.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :submit_options_form
        route "/admin/submit-options"
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

      submit do
        create label: "Create Item", disabled: false, restricted: true

        update do
          label "Save Item"
          disabled fn _state -> false end
          restricted fn _state -> false end
          visible fn _state -> true end
        end

        cancel label: "Go Back", visible: false

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

defmodule MishkaGervaz.Test.Resources.NoButtonsForm do
  @moduledoc """
  Test resource with empty submit block — no buttons should render.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :no_buttons_form
        route "/admin/no-buttons"
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

      submit do
        position :bottom
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

defmodule MishkaGervaz.Test.Resources.PasswordForm do
  @moduledoc """
  Test resource for the password field type.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    table do
      identity do
        name :password_form_table
        route "/admin/password"
      end

      columns do
        column :email
      end
    end

    form do
      identity do
        name :password_form
        route "/admin/password"
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
        field :email, :text, required: true

        field :password, :password do
          virtual true

          ui do
            label "Password"
            placeholder "Enter password"
            autocomplete "new-password"
          end
        end

        field :password_confirmation, :password do
          virtual true

          ui do
            label "Confirm Password"
            placeholder "Re-enter password"
            autocomplete "new-password"
          end
        end
      end

      groups do
        group :credentials do
          fields [:email, :password, :password_confirmation]

          ui do
            label "Credentials"
            columns 2
          end
        end
      end

      submit do
        create label: "Create Account"
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :master_read do
      prepare build(sort: [inserted_at: :desc])
    end

    read :master_get do
      get? true
    end

    create :master_create do
      accept [:email]

      argument :password, :string do
        allow_nil? true
        sensitive? true
      end

      argument :password_confirmation, :string do
        allow_nil? true
        sensitive? true
      end
    end

    update :master_update do
      accept [:email]

      argument :password, :string do
        allow_nil? true
        sensitive? true
      end

      argument :password_confirmation, :string do
        allow_nil? true
        sensitive? true
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end

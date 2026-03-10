defmodule MishkaGervaz.Test.FormWebHelpers do
  @moduledoc """
  Helper functions for form web layer tests.

  Provides builders for State, Static, and Socket structs
  without depending on Spark DSL compilation.
  """

  alias MishkaGervaz.Form.Web.State
  alias MishkaGervaz.Form.Web.State.Static

  @spec build_static(keyword()) :: Static.t()
  def build_static(opts \\ []) do
    %Static{
      id: Keyword.get(opts, :id, "test-form"),
      resource: Keyword.get(opts, :resource, MishkaGervaz.Test.FormWebHelpers.FakeResource),
      stream_name: Keyword.get(opts, :stream_name, :test_form_stream),
      config: Keyword.get(opts, :config, %{}),
      fields: Keyword.get(opts, :fields, default_fields()),
      field_order: Keyword.get(opts, :field_order, [:title, :content, :status]),
      groups: Keyword.get(opts, :groups, default_groups()),
      steps: Keyword.get(opts, :steps, []),
      uploads: Keyword.get(opts, :uploads, []),
      submit:
        Keyword.get(opts, :submit, %{
          create: %{label: "Create", disabled: false, restricted: false, visible: true},
          update: %{label: "Update", disabled: false, restricted: false, visible: true},
          cancel: %{label: "Cancel", disabled: false, restricted: false, visible: true},
          position: :bottom
        }),
      hooks: Keyword.get(opts, :hooks, %{}),
      ui_adapter: Keyword.get(opts, :ui_adapter, MishkaGervaz.UIAdapters.Tailwind),
      ui_adapter_opts: Keyword.get(opts, :ui_adapter_opts, []),
      template: Keyword.get(opts, :template, MishkaGervaz.Form.Templates.Standard),
      theme: Keyword.get(opts, :theme, nil),
      features: Keyword.get(opts, :features, []),
      preloads: Keyword.get(opts, :preloads, []),
      layout_mode: Keyword.get(opts, :layout_mode, :standard),
      layout_columns: Keyword.get(opts, :layout_columns, 1),
      layout_navigation: Keyword.get(opts, :layout_navigation, :sequential),
      layout_persistence: Keyword.get(opts, :layout_persistence, :none)
    }
  end

  @spec build_state(keyword()) :: State.t()
  def build_state(opts \\ []) do
    static = Keyword.get(opts, :static, build_static(Keyword.get(opts, :static_opts, [])))

    %State{
      static: static,
      current_user: Keyword.get(opts, :current_user, %{id: "user-1", role: :admin}),
      master_user?: Keyword.get(opts, :master_user?, true),
      mode: Keyword.get(opts, :mode, :create),
      current_step: Keyword.get(opts, :current_step, nil),
      step_states: Keyword.get(opts, :step_states, %{}),
      wizard_history: Keyword.get(opts, :wizard_history, []),
      form: Keyword.get(opts, :form, nil),
      loading: Keyword.get(opts, :loading, :loaded),
      errors: Keyword.get(opts, :errors, %{}),
      field_values: Keyword.get(opts, :field_values, %{}),
      relation_options: Keyword.get(opts, :relation_options, %{}),
      combobox_options: Keyword.get(opts, :combobox_options, %{}),
      upload_state: Keyword.get(opts, :upload_state, %{}),
      existing_files: Keyword.get(opts, :existing_files, %{}),
      dirty?: Keyword.get(opts, :dirty?, false),
      defaults: Keyword.get(opts, :defaults, nil)
    }
  end

  @spec build_socket(State.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  def build_socket(state, opts \\ []) do
    base_assigns = %{
      __changed__: %{},
      form_state: state,
      flash: %{},
      live_action: :index
    }

    extra_assigns = Keyword.get(opts, :assigns, %{})
    assigns = Map.merge(base_assigns, extra_assigns)

    %Phoenix.LiveView.Socket{
      assigns: assigns,
      private: %{
        lifecycle: %{handle_event: [], after_render: []},
        assign_new: %{},
        changed: %{},
        connected?: true,
        live_temp: %{}
      },
      endpoint: MishkaGervazWeb.Endpoint,
      id: Keyword.get(opts, :socket_id, "test-socket"),
      root_pid: self(),
      router: nil,
      view: nil
    }
  end

  @spec default_fields() :: list(map())
  def default_fields do
    [
      %{
        name: :title,
        type: :text,
        required: true,
        disabled: false,
        options: [],
        ui: %{label: "Title", placeholder: "Enter title...", class: nil},
        depends_on: nil
      },
      %{
        name: :content,
        type: :textarea,
        required: false,
        disabled: false,
        options: [],
        ui: %{label: "Content", placeholder: nil, class: nil},
        depends_on: nil
      },
      %{
        name: :status,
        type: :select,
        required: false,
        disabled: false,
        options: [{:draft, "Draft"}, {:published, "Published"}],
        ui: %{label: "Status", placeholder: nil, class: nil},
        depends_on: nil
      }
    ]
  end

  @spec default_groups() :: list(map())
  def default_groups do
    [
      %{
        name: :general,
        fields: [:title, :content],
        resolved_label: "General",
        resolved_fields: default_fields() |> Enum.take(2),
        collapsible: false
      },
      %{
        name: :settings,
        fields: [:status],
        resolved_label: "Settings",
        resolved_fields: default_fields() |> Enum.drop(2),
        collapsible: true
      }
    ]
  end

  @spec upload_config(atom(), keyword()) :: map()
  def upload_config(name, opts \\ []) do
    %{
      name: name,
      field: Keyword.get(opts, :field, nil),
      accept: Keyword.get(opts, :accept, "image/*"),
      max_entries: Keyword.get(opts, :max_entries, 1),
      max_file_size: Keyword.get(opts, :max_file_size, 8_000_000),
      auto_upload: Keyword.get(opts, :auto_upload, false),
      show_preview: Keyword.get(opts, :show_preview, true),
      dropzone_text: Keyword.get(opts, :dropzone_text, "Drop files here"),
      style: Keyword.get(opts, :style, :dropzone),
      chunk_size: Keyword.get(opts, :chunk_size, nil),
      chunk_timeout: Keyword.get(opts, :chunk_timeout, nil),
      external: Keyword.get(opts, :external, nil),
      writer: Keyword.get(opts, :writer, nil),
      existing: Keyword.get(opts, :existing, nil),
      ui: Keyword.get(opts, :ui, %{label: to_string(name), icon: nil, class: nil})
    }
  end

  @spec state_with_uploads(keyword()) :: State.t()
  def state_with_uploads(opts \\ []) do
    uploads =
      Keyword.get(opts, :uploads, [
        upload_config(:cover, accept: "image/*", max_entries: 1),
        upload_config(:documents, accept: ".pdf,.doc", max_entries: 5, field: :attachments)
      ])

    static_opts = Keyword.merge([uploads: uploads], Keyword.get(opts, :static_opts, []))
    build_state(Keyword.merge(opts, static_opts: static_opts))
  end
end

defmodule MishkaGervaz.Form.Entities.Upload do
  @moduledoc """
  Entity struct for file upload configuration.

  This module defines the struct and schema for uploads, following Ash's
  entity pattern with `opt_schema` and `transform/1`.
  """

  @type t :: %__MODULE__{
          name: atom(),
          field: atom() | nil,
          accept: String.t() | nil,
          max_entries: pos_integer(),
          max_file_size: pos_integer(),
          show_preview: boolean(),
          dropzone_text: String.t() | (-> String.t()) | nil,
          auto_upload: boolean(),
          style: :dropzone | :file_input | :custom,
          chunk_size: pos_integer() | nil,
          chunk_timeout: pos_integer() | nil,
          external: (map(), Phoenix.LiveView.Socket.t() -> any()) | atom() | nil,
          writer: atom() | nil,
          existing: atom() | (map() -> list()) | nil,
          ui: __MODULE__.Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    :__identifier__,
    field: nil,
    accept: nil,
    max_entries: 1,
    max_file_size: 8_000_000,
    show_preview: true,
    dropzone_text: nil,
    auto_upload: false,
    style: :dropzone,
    chunk_size: nil,
    chunk_timeout: nil,
    external: nil,
    writer: nil,
    existing: nil,
    ui: nil,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Upload identifier (matches allow_upload key)."
    ],
    field: [
      type: :atom,
      doc: "Form field this upload is associated with."
    ],
    accept: [
      type: :string,
      doc: "Accepted file types (e.g. \"image/*,.pdf\")."
    ],
    max_entries: [
      type: :pos_integer,
      default: 1,
      doc: "Maximum number of files."
    ],
    max_file_size: [
      type: :pos_integer,
      default: 8_000_000,
      doc: "Maximum file size in bytes."
    ],
    show_preview: [
      type: :boolean,
      default: true,
      doc: "Show file preview."
    ],
    dropzone_text: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Dropzone placeholder text."
    ],
    auto_upload: [
      type: :boolean,
      default: false,
      doc: "Auto-upload on file selection."
    ],
    style: [
      type: {:in, [:dropzone, :file_input, :custom]},
      default: :dropzone,
      doc:
        "Upload UI style: :dropzone (drag-and-drop), :file_input (standard file picker), :custom (bare live_file_input)."
    ],
    chunk_size: [
      type: :pos_integer,
      doc: "Bytes per chunk for chunked uploads."
    ],
    chunk_timeout: [
      type: :pos_integer,
      doc: "Chunk timeout in milliseconds."
    ],
    external: [
      type: {:or, [{:fun, 2}, :atom]},
      doc: "External uploader module or function (e.g., for S3 direct uploads)."
    ],
    writer: [
      type: :atom,
      doc: "Custom UploadWriter module for processing upload chunks."
    ],
    existing: [
      type: {:or, [:atom, {:fun, 1}]},
      doc:
        "How to extract existing files from a record in edit mode. Atom field name or function receiving the record."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the upload after DSL compilation.

  Extracts the nested ui entity from the list wrapper.
  """
  def transform(%__MODULE__{} = upload) do
    {:ok, extract_ui(upload)}
  end

  def transform(upload), do: {:ok, upload}

  defp extract_ui(%{ui: [ui | _]} = upload), do: %{upload | ui: ui}
  defp extract_ui(%{ui: ui} = upload) when is_struct(ui), do: upload
  defp extract_ui(upload), do: upload
end

defmodule MishkaGervaz.Form.Entities.Upload.Ui do
  @moduledoc """
  UI configuration for file uploads.
  """

  @type t :: %__MODULE__{
          label: String.t() | (-> String.t()) | nil,
          icon: String.t() | nil,
          class: String.t() | nil,
          preview_class: String.t() | nil,
          extra: map(),
          __spark_metadata__: map() | nil
        }

  defstruct label: nil,
            icon: nil,
            class: nil,
            preview_class: nil,
            extra: %{},
            __spark_metadata__: nil

  @opt_schema [
    label: [
      type: {:or, [:string, {:fun, 0}]},
      doc: "Upload label."
    ],
    icon: [
      type: :string,
      doc: "Upload icon."
    ],
    class: [
      type: :string,
      doc: "Upload CSS classes."
    ],
    preview_class: [
      type: :string,
      doc: "Preview area CSS classes."
    ],
    extra: [
      type: :map,
      default: %{},
      doc: "Additional options."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  def transform(ui), do: {:ok, ui}
end

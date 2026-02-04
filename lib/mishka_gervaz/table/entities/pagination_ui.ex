defmodule MishkaGervaz.Table.Entities.Pagination.Ui do
  @moduledoc """
  UI/presentation configuration for pagination.
  """

  @type t :: %__MODULE__{
          load_more_label: String.t(),
          loading_text: String.t(),
          show_total: boolean(),
          prev_label: String.t(),
          next_label: String.t(),
          first_label: String.t(),
          last_label: String.t(),
          page_info_format: String.t(),
          __spark_metadata__: map() | nil
        }

  defstruct load_more_label: "Load More",
            loading_text: "Loading...",
            show_total: true,
            prev_label: "Previous",
            next_label: "Next",
            first_label: "First",
            last_label: "Last",
            page_info_format: "Page {page} of {total}",
            __spark_metadata__: nil

  @opt_schema [
    load_more_label: [
      type: :string,
      default: "Load More",
      doc: "Load more button text."
    ],
    loading_text: [
      type: :string,
      default: "Loading...",
      doc: "Loading indicator text."
    ],
    show_total: [
      type: :boolean,
      default: true,
      doc: "Show total record count."
    ],
    prev_label: [
      type: :string,
      default: "Previous",
      doc: "Previous page button text."
    ],
    next_label: [
      type: :string,
      default: "Next",
      doc: "Next page button text."
    ],
    first_label: [
      type: :string,
      default: "First",
      doc: "First page button text."
    ],
    last_label: [
      type: :string,
      default: "Last",
      doc: "Last page button text."
    ],
    page_info_format: [
      type: :string,
      default: "Page {page} of {total}",
      doc: "Page info format. Use {page}, {total}, {from}, {to}, {count}."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the UI after DSL compilation.
  """
  def transform(%__MODULE__{} = ui), do: {:ok, ui}
  def transform(ui), do: {:ok, ui}
end

defmodule MishkaGervaz.Table.Entities.Pagination do
  @moduledoc """
  Entity struct for pagination configuration.
  """

  alias __MODULE__.Ui

  @type t :: %__MODULE__{
          type: :infinite | :numbered | :load_more | nil,
          page_size: pos_integer() | nil,
          page_size_options: [pos_integer()] | nil,
          max_page_size: pos_integer() | nil,
          ui: Ui.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct type: nil,
            page_size: nil,
            page_size_options: nil,
            max_page_size: nil,
            ui: nil,
            __spark_metadata__: nil

  @opt_schema [
    type: [
      type: {:in, [:infinite, :numbered, :load_more]},
      doc: "Pagination style. Default: :load_more"
    ],
    page_size: [
      type: :integer,
      doc: "Records per page. Default: 20"
    ],
    page_size_options: [
      type: {:list, :integer},
      doc: "Available page size options. Default: [10, 25, 50, 100]"
    ],
    max_page_size: [
      type: :pos_integer,
      doc: "Maximum allowed page size. Clamps URL-provided values. Default: 150"
    ]
  ]

  @defaults %{
    type: :load_more,
    page_size: 20,
    page_size_options: [10, 25, 50, 100],
    max_page_size: 150
  }

  @doc false
  def opt_schema, do: @opt_schema

  @doc "Returns the default values for pagination fields."
  def defaults, do: @defaults

  @doc "Returns the default value for a specific field."
  def default(key), do: Map.get(@defaults, key)

  @doc """
  Transform the pagination after DSL compilation.
  """
  def transform(%__MODULE__{} = pagination) do
    pagination = extract_ui(pagination)
    {:ok, pagination}
  end

  def transform(pagination), do: {:ok, pagination}

  defp extract_ui(%{ui: [ui | _]} = pagination), do: %{pagination | ui: ui}
  defp extract_ui(%{ui: ui} = pagination) when is_struct(ui, Ui), do: pagination
  defp extract_ui(pagination), do: %{pagination | ui: struct(Ui)}
end

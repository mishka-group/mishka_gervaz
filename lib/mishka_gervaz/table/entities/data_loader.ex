defmodule MishkaGervaz.Table.Entities.DataLoader do
  @moduledoc """
  Entity struct for data_loader configuration.

  Allows overriding data loading modules at DSL level.

  ## Usage

  Override entire data_loader module (positional argument):

      data_loader MyApp.Table.CustomDataLoader

  Override specific sub-builders (block syntax):

      data_loader do
        query MyApp.Table.DataLoader.QueryBuilder
        filter_parser MyApp.Table.DataLoader.FilterParser
        pagination MyApp.Table.DataLoader.PaginationHandler
        tenant MyApp.Table.DataLoader.TenantResolver
        hooks MyApp.Table.DataLoader.HookRunner
        relation MyApp.Table.DataLoader.RelationLoader
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `query` - `MishkaGervaz.Table.Web.DataLoader.QueryBuilder.Default`
  - `filter_parser` - `MishkaGervaz.Table.Web.DataLoader.FilterParser.Default`
  - `pagination` - `MishkaGervaz.Table.Web.DataLoader.PaginationHandler.Default`
  - `tenant` - `MishkaGervaz.Table.Web.DataLoader.TenantResolver.Default`
  - `hooks` - `MishkaGervaz.Table.Web.DataLoader.HookRunner.Default`
  - `relation` - `MishkaGervaz.Table.Web.DataLoader.RelationLoader.Default`
  """

  @type t :: %__MODULE__{
          module: module() | nil,
          query: module() | nil,
          filter_parser: module() | nil,
          pagination: module() | nil,
          tenant: module() | nil,
          hooks: module() | nil,
          relation: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct module: nil,
            query: nil,
            filter_parser: nil,
            pagination: nil,
            tenant: nil,
            hooks: nil,
            relation: nil,
            __spark_metadata__: nil

  @opt_schema [
    module: [
      type: :atom,
      doc: """
      Override the entire data_loader module. When set, all other options are ignored.
      The module must `use MishkaGervaz.Table.Web.DataLoader`.
      """
    ],
    query: [
      type: :atom,
      doc: """
      Query builder module. Must `use MishkaGervaz.Table.Web.DataLoader.QueryBuilder`.
      Builds queries with filters and sorting.
      """
    ],
    filter_parser: [
      type: :atom,
      doc: """
      Filter parser module. Must `use MishkaGervaz.Table.Web.DataLoader.FilterParser`.
      Parses raw filter values from form submissions.
      """
    ],
    pagination: [
      type: :atom,
      doc: """
      Pagination handler module. Must `use MishkaGervaz.Table.Web.DataLoader.PaginationHandler`.
      Handles page loading and pagination calculations.
      """
    ],
    tenant: [
      type: :atom,
      doc: """
      Tenant resolver module. Must `use MishkaGervaz.Table.Web.DataLoader.TenantResolver`.
      Resolves tenant and read actions based on state.
      """
    ],
    hooks: [
      type: :atom,
      doc: """
      Hook runner module. Must `use MishkaGervaz.Table.Web.DataLoader.HookRunner`.
      Executes hooks during data loading.
      """
    ],
    relation: [
      type: :atom,
      doc: """
      Relation loader module. Must `use MishkaGervaz.Table.Web.DataLoader.RelationLoader`.
      Loads options for relation filters (search, load_more, resolve_selected).
      """
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the data_loader after DSL compilation.
  """
  def transform(%__MODULE__{} = data_loader) do
    {:ok, data_loader}
  end

  def transform(data_loader), do: {:ok, data_loader}
end

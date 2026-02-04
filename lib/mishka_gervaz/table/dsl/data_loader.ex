defmodule MishkaGervaz.Table.Dsl.DataLoader do
  @moduledoc """
  DataLoader entity DSL definition for table configuration.

  Allows overriding data loading modules at DSL level.
  Supports both positional argument and block syntax:

  ## Usage

  Override entire data_loader module (positional argument):

      mishka_gervaz do
        table do
          data_loader MyApp.Table.CustomDataLoader
        end
      end

  Override specific sub-builders (block syntax):

      mishka_gervaz do
        table do
          data_loader do
            query MyApp.Table.DataLoader.QueryBuilder
            filter_parser MyApp.Table.DataLoader.FilterParser
            pagination MyApp.Table.DataLoader.PaginationHandler
            tenant MyApp.Table.DataLoader.TenantResolver
            hooks MyApp.Table.DataLoader.HookRunner
            relation MyApp.Table.DataLoader.RelationLoader
          end
        end
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

  alias MishkaGervaz.Table.Entities.DataLoader

  @doc """
  Returns the data_loader entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :data_loader,
      describe: "Override data loading modules.",
      target: DataLoader,
      args: [:module],
      schema: DataLoader.opt_schema(),
      singleton_entity_keys: [:data_loader],
      transform: {DataLoader, :transform, []}
    }
  end
end

defmodule MishkaGervaz.Form.Dsl.DataLoader do
  @moduledoc """
  DataLoader entity DSL definition for form configuration.

  Allows overriding data loading modules at DSL level.
  Supports both positional argument and block syntax:

  ## Usage

  Override entire data_loader module (positional argument):

      mishka_gervaz do
        form do
          data_loader MyApp.Form.CustomDataLoader
        end
      end

  Override specific sub-builders (block syntax):

      mishka_gervaz do
        form do
          data_loader do
            record MyApp.Form.DataLoader.RecordLoader
            tenant MyApp.Form.DataLoader.TenantResolver
            relation MyApp.Form.DataLoader.RelationLoader
            hooks MyApp.Form.DataLoader.HookRunner
          end
        end
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `record` - `MishkaGervaz.Form.Web.DataLoader.RecordLoader.Default`
  - `tenant` - `MishkaGervaz.Form.Web.DataLoader.TenantResolver.Default`
  - `relation` - `MishkaGervaz.Form.Web.DataLoader.RelationLoader.Default`
  - `hooks` - `MishkaGervaz.Form.Web.DataLoader.HookRunner.Default`
  """

  alias MishkaGervaz.Form.Entities.DataLoader

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

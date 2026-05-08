defmodule MishkaGervaz.Form.Entities.DataLoader do
  @moduledoc """
  Data-loader module overrides — replace the default record / tenant /
  relation / hook loaders with your own implementations.

  Two calling styles. Pass a module positionally to override the entire
  data loader, or use the block form to swap individual sub-builders
  while keeping the defaults for the rest:

      # Whole-module override
      data_loader MyApp.Form.CustomDataLoader

      # Per-sub-builder overrides
      data_loader do
        record MyApp.Form.DataLoader.RecordLoader
        tenant MyApp.Form.DataLoader.TenantResolver
        relation MyApp.Form.DataLoader.RelationLoader
        hooks MyApp.Form.DataLoader.HookRunner
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

    * `record`   — `MishkaGervaz.Form.Web.DataLoader.RecordLoader.Default`
    * `tenant`   — `MishkaGervaz.Form.Web.DataLoader.TenantResolver.Default`
    * `relation` — `MishkaGervaz.Form.Web.DataLoader.RelationLoader.Default`
    * `hooks`    — `MishkaGervaz.Form.Web.DataLoader.HookRunner.Default`

  See `MishkaGervaz.Form.Dsl.DataLoader` for the DSL declaration.
  """

  @type t :: %__MODULE__{
          module: module() | nil,
          record: module() | nil,
          tenant: module() | nil,
          relation: module() | nil,
          hooks: module() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct module: nil,
            record: nil,
            tenant: nil,
            relation: nil,
            hooks: nil,
            __spark_metadata__: nil

  @opt_schema [
    module: [
      type: :atom,
      doc: """
      Override the entire data_loader module. When set, all other options are ignored.
      The module must `use MishkaGervaz.Form.Web.DataLoader`.
      """
    ],
    record: [
      type: :atom,
      doc: """
      Record loader module. Must `use MishkaGervaz.Form.Web.DataLoader.RecordLoader`.
      Loads records for edit mode and creates AshPhoenix.Form structs.
      """
    ],
    tenant: [
      type: :atom,
      doc: """
      Tenant resolver module. Must `use MishkaGervaz.Form.Web.DataLoader.TenantResolver`.
      Resolves tenant and actions based on state.
      """
    ],
    relation: [
      type: :atom,
      doc: """
      Relation loader module. Must `use MishkaGervaz.Form.Web.DataLoader.RelationLoader`.
      Loads options for relation/select fields.
      """
    ],
    hooks: [
      type: :atom,
      doc: """
      Hook runner module. Must `use MishkaGervaz.Form.Web.DataLoader.HookRunner`.
      Executes hooks during data loading.
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

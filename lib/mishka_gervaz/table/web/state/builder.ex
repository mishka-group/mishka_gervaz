defmodule MishkaGervaz.Table.Web.State.Builder do
  @moduledoc """
  Common macro for all state sub-builders.

  Provides consistent structure and defoverridable pattern for:
  - ColumnBuilder
  - FilterBuilder
  - ActionBuilder
  - Presentation
  - UrlSync
  - Access

  ## Usage

      defmodule MishkaGervaz.Table.Web.State.ColumnBuilder do
        use MishkaGervaz.Table.Web.State.Builder,
          functions: [build: 2, resolve_type: 2]

        def build(config, resource) do
          # implementation
        end
      end

  ## User Override

      defmodule MyApp.Table.ColumnBuilder do
        use MishkaGervaz.Table.Web.State.ColumnBuilder

        def resolve_type(column, attrs) do
          case column.name do
            :special -> MyApp.SpecialType
            _ -> super(column, attrs)
          end
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @doc """
      Returns information about the builder module.

      ## Parameters

        - `info_type` - The type of information to return (`:module`)

      ## Returns

        - The module name when `info_type` is `:module`
      """
      @spec __builder_info__(:module) :: module()
      def __builder_info__(:module), do: __MODULE__
    end
  end
end

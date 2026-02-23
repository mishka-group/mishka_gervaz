defmodule MishkaGervaz.Form.Web.DataLoader.Builder do
  @moduledoc """
  Common macro for all form DataLoader sub-builders.

  Provides consistent structure and defoverridable pattern for:
  - RecordLoader
  - TenantResolver
  - RelationLoader
  - HookRunner
  """

  defmacro __using__(_opts) do
    quote do
      @spec __builder_info__(:module) :: module()
      def __builder_info__(:module), do: __MODULE__
    end
  end
end

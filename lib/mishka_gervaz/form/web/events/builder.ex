defmodule MishkaGervaz.Form.Web.Events.Builder do
  @moduledoc """
  Common macro for all form Events sub-builders.

  Provides consistent structure and defoverridable pattern for:
  - ValidationHandler
  - SubmitHandler
  - StepHandler
  - UploadHandler
  - RelationHandler
  - HookRunner
  - SanitizationHandler
  """

  defmacro __using__(_opts) do
    quote do
      @spec __builder_info__(:module) :: module()
      def __builder_info__(:module), do: __MODULE__
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.Builder do
  @moduledoc """
  Common macro for all form state sub-builders.

  Provides consistent structure and defoverridable pattern for:
  - FieldBuilder
  - GroupBuilder
  - StepBuilder
  - Presentation
  - Access

  ## Usage

      defmodule MishkaGervaz.Form.Web.State.FieldBuilder do
        use MishkaGervaz.Form.Web.State.Builder,
          functions: [build: 2, resolve_type: 2]

        def build(config, resource) do
          # implementation
        end
      end

  ## User Override

      defmodule MyApp.Form.FieldBuilder do
        use MishkaGervaz.Form.Web.State.FieldBuilder

        def resolve_type(field, attrs) do
          case field.name do
            :special -> MyApp.SpecialType
            _ -> super(field, attrs)
          end
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @spec __builder_info__(:module) :: module()
      def __builder_info__(:module), do: __MODULE__
    end
  end
end

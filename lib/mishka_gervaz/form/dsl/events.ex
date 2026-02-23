defmodule MishkaGervaz.Form.Dsl.Events do
  @moduledoc """
  Events entity DSL definition for form configuration.

  Allows overriding event handling modules at DSL level.
  Supports both positional argument and block syntax:

  ## Usage

  Override entire events module (positional argument):

      mishka_gervaz do
        form do
          events MyApp.Form.CustomEvents
        end
      end

  Override specific sub-builders (block syntax):

      mishka_gervaz do
        form do
          events do
            sanitization MyApp.Form.Events.SanitizationHandler
            validation MyApp.Form.Events.ValidationHandler
            submit MyApp.Form.Events.SubmitHandler
            step MyApp.Form.Events.StepHandler
            upload MyApp.Form.Events.UploadHandler
            relation MyApp.Form.Events.RelationHandler
            hooks MyApp.Form.Events.HookRunner
          end
        end
      end

  ## Defaults

  When no overrides are specified, the following defaults are used:

  - `sanitization` - `MishkaGervaz.Form.Web.Events.SanitizationHandler.Default`
  - `validation` - `MishkaGervaz.Form.Web.Events.ValidationHandler.Default`
  - `submit` - `MishkaGervaz.Form.Web.Events.SubmitHandler.Default`
  - `step` - `MishkaGervaz.Form.Web.Events.StepHandler.Default`
  - `upload` - `MishkaGervaz.Form.Web.Events.UploadHandler.Default`
  - `relation` - `MishkaGervaz.Form.Web.Events.RelationHandler.Default`
  - `hooks` - `MishkaGervaz.Form.Web.Events.HookRunner.Default`
  """

  alias MishkaGervaz.Form.Entities.Events

  @doc """
  Returns the events entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :events,
      describe: "Override event handling modules.",
      target: Events,
      args: [:module],
      schema: Events.opt_schema(),
      singleton_entity_keys: [:events],
      transform: {Events, :transform, []}
    }
  end
end

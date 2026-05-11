defmodule MishkaGervaz.Form.Web.Events.ValidationHandlerTest do
  @moduledoc """
  Direct tests for `MishkaGervaz.Form.Web.Events.ValidationHandler.Default`.

  `validate/3,4,5` requires a real `Phoenix.HTML.Form` + State + socket and is
  exercised via integration in `events_test.exs`. Here we cover
  `build_errors/1` (the only callback that's purely a data-shape function).
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Form.Web.Events.ValidationHandler.Default, as: ValidationHandler

  describe "build_errors/1" do
    test "returns %{} for a form with no errors" do
      form = %Phoenix.HTML.Form{errors: []}
      assert ValidationHandler.build_errors(form) == %{}
    end

    test "groups errors by field" do
      form = %Phoenix.HTML.Form{
        errors: [
          {:title, {"can't be blank", []}},
          {:title, {"is too short", []}},
          {:body, {"is required", []}}
        ]
      }

      result = ValidationHandler.build_errors(form)

      assert result[:title] == ["can't be blank", "is too short"]
      assert result[:body] == ["is required"]
    end

    test "interpolates %{key} placeholders from opts" do
      form = %Phoenix.HTML.Form{
        errors: [{:age, {"must be at least %{min}", [min: 18]}}]
      }

      assert ValidationHandler.build_errors(form) == %{age: ["must be at least 18"]}
    end

    test "supports multiple interpolations in one message" do
      form = %Phoenix.HTML.Form{
        errors: [
          {:length, {"must be between %{min} and %{max} chars", [min: 3, max: 10]}}
        ]
      }

      assert ValidationHandler.build_errors(form) ==
               %{length: ["must be between 3 and 10 chars"]}
    end
  end

  describe "override pattern" do
    test "user can override build_errors via use" do
      defmodule TestValidationOverride do
        use MishkaGervaz.Form.Web.Events.ValidationHandler

        def build_errors(_form), do: %{custom: ["overridden"]}
      end

      assert TestValidationOverride.build_errors(%Phoenix.HTML.Form{}) ==
               %{custom: ["overridden"]}
    end
  end
end

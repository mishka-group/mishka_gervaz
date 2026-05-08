defmodule MishkaGervaz.Form.Web.Events.SanitizationHandler do
  @moduledoc """
  Sanitizes form input values.

  ## Overridable Functions

  - `sanitize/1` - Sanitize a string value
  - `sanitize_params/1` - Sanitize form params map

  ## User Override

      defmodule MyApp.Form.SanitizationHandler do
        use MishkaGervaz.Form.Web.Events.SanitizationHandler

        def sanitize(value) do
          value |> super() |> String.trim()
        end
      end

  See `MishkaGervaz.Form.Web.Events`,
  `MishkaGervaz.Form.Web.Events.Helpers` (where `sanitize_string/1` and
  `sanitize_list_item/2` live), and the sibling sub-handlers.
  """

  defmacro __using__(_opts) do
    quote do
      alias MishkaGervaz.Form.Web.Events.Helpers, as: EventsHelpers

      @doc """
      Sanitize a single string value.

      Strips HTML tags and trims whitespace. Delegates to
      `MishkaGervaz.Form.Web.Events.Helpers.sanitize_string/1`.
      """
      @spec sanitize(any()) :: any()
      def sanitize(value), do: EventsHelpers.sanitize_string(value)

      @doc """
      Sanitize a map of form params.

      Recursively sanitizes string values in the params map.
      """
      @spec sanitize_params(map()) :: map()
      def sanitize_params(params) when is_map(params) do
        Map.new(params, fn
          {key, value} when is_binary(value) ->
            {key, sanitize(value)}

          {key, value} when is_map(value) ->
            {key, sanitize_params(value)}

          {key, value} when is_list(value) ->
            sanitize_params_fn = &sanitize_params/1
            {key, Enum.map(value, &EventsHelpers.sanitize_list_item(&1, sanitize_params_fn))}

          {key, value} ->
            {key, value}
        end)
      end

      defoverridable sanitize: 1, sanitize_params: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.SanitizationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.SanitizationHandler
end

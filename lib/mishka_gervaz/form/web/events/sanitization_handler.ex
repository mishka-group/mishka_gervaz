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
  """

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      @doc """
      Sanitize a single string value.

      Strips HTML tags and trims whitespace.
      """
      @spec sanitize(any()) :: any()
      def sanitize(value) when is_binary(value) do
        value
        |> String.replace(~r/<[^>]*>/, "")
        |> String.trim()
      end

      def sanitize(value), do: value

      @doc """
      Sanitize a map of form params.

      Recursively sanitizes string values in the params map.
      """
      @spec sanitize_params(map()) :: map()
      def sanitize_params(params) when is_map(params) do
        Map.new(params, fn
          {key, value} when is_binary(value) -> {key, sanitize(value)}
          {key, value} when is_map(value) -> {key, sanitize_params(value)}
          {key, value} when is_list(value) -> {key, Enum.map(value, &sanitize_list_item/1)}
          {key, value} -> {key, value}
        end)
      end

      @spec sanitize_list_item(any()) :: any()
      defp sanitize_list_item(item) when is_binary(item), do: sanitize(item)
      defp sanitize_list_item(item) when is_map(item), do: sanitize_params(item)
      defp sanitize_list_item(item), do: item

      defoverridable sanitize: 1, sanitize_params: 1
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.SanitizationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.SanitizationHandler
end

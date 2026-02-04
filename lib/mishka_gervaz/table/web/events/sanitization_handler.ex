defmodule MishkaGervaz.Table.Web.Events.SanitizationHandler do
  @moduledoc """
  Handles input sanitization for Events module.

  This module provides sanitization functions to prevent XSS and other
  injection attacks from user input in event parameters.

  ## Customization

  You can create a custom SanitizationHandler by using this module:

      defmodule MyApp.CustomSanitizationHandler do
        use MishkaGervaz.Table.Web.Events.SanitizationHandler

        # Custom sanitization that allows some HTML tags
        def sanitize(value) when is_binary(value) do
          HtmlSanitizeEx.basic_html(value)
        end
      end

  Then configure it in your resource's DSL:

      mishka_gervaz do
        table do
          events do
            sanitization MyApp.CustomSanitizationHandler
          end
        end
      end
  """

  @doc """
  Sanitizes a value to prevent XSS and injection attacks.

  ## Examples

      iex> sanitize("<script>alert('xss')</script>test")
      "alert('xss')test"

      iex> sanitize(123)
      123

  """
  @callback sanitize(value :: any()) :: any()

  @doc """
  Sanitizes a column name for sorting.

  Returns the sanitized value as an existing atom, or raises ArgumentError
  if the atom doesn't exist.
  """
  @callback sanitize_column(column :: String.t()) :: atom()

  @doc """
  Sanitizes a page number from params.

  Returns an integer page number.
  """
  @callback sanitize_page(page :: String.t() | integer()) :: integer()

  @optional_callbacks sanitize_column: 1, sanitize_page: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.SanitizationHandler

      @impl true
      @spec sanitize(any()) :: any()
      def sanitize(value) when is_binary(value) do
        HtmlSanitizeEx.strip_tags(value)
      rescue
        _ -> value
      end

      def sanitize(value), do: value

      @impl true
      @spec sanitize_column(binary()) :: atom()
      def sanitize_column(column) when is_binary(column) do
        column
        |> sanitize()
        |> String.to_existing_atom()
      end

      @impl true
      @spec sanitize_page(binary() | integer() | any()) :: integer()
      def sanitize_page(page) when is_binary(page) do
        page
        |> sanitize()
        |> String.to_integer()
      end

      def sanitize_page(page) when is_integer(page), do: page
      def sanitize_page(_), do: 1

      defoverridable sanitize: 1, sanitize_column: 1, sanitize_page: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.SanitizationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.SanitizationHandler
end

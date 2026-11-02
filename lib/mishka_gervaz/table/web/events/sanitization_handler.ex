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

  See `MishkaGervaz.Table.Web.Events`,
  and the sibling handlers `RecordHandler`, `SelectionHandler`,
  `BulkActionHandler`, `HookRunner`, `RelationFilterHandler`.
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
  Reads a page number or a page size from an event's params.

  Returns the positive whole number it spells, or `nil` for anything else (`0`, `-2`, `two`, `1.5`,
  a list), the way `MishkaGervaz.Table.Web.UrlSync` reads the page from the URL. A `go_to_page`
  event with `nil` opens page 1, and a `change_page_size` event with `nil` is ignored.
  """
  @callback sanitize_page(page :: term()) :: pos_integer() | nil

  @optional_callbacks sanitize_column: 1, sanitize_page: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour MishkaGervaz.Table.Web.Events.SanitizationHandler

      @impl true
      @spec sanitize(any()) :: any()
      def sanitize(value) when is_binary(value), do: MishkaGervaz.Helpers.strip_tags(value)

      def sanitize(value), do: value

      @impl true
      @spec sanitize_column(binary()) :: atom()
      def sanitize_column(column) when is_binary(column) do
        column
        |> sanitize()
        |> String.to_existing_atom()
      end

      @impl true
      @spec sanitize_page(term()) :: pos_integer() | nil
      def sanitize_page(page), do: page |> sanitize() |> MishkaGervaz.Helpers.positive_integer()

      defoverridable sanitize: 1, sanitize_column: 1, sanitize_page: 1
    end
  end
end

defmodule MishkaGervaz.Table.Web.Events.SanitizationHandler.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.Events.SanitizationHandler
end

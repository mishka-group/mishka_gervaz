defmodule MishkaGervaz.Table.Web.DataLoader.FilterParser do
  @moduledoc """
  Parses raw filter values from form submissions.

  ## Overridable Functions

  - `parse_filter_values/2` - Parse raw filter values using filter configs
  - `parse_single_filter/3` - Parse a single filter value

  ## User Override

      defmodule MyApp.Table.DataLoader.FilterParser do
        use MishkaGervaz.Table.Web.DataLoader.FilterParser

        def parse_single_filter(field_atom, raw_value, filter_config) do
          # Custom parsing logic
          case field_atom do
            :custom_field -> custom_parse(raw_value)
            _ -> super(field_atom, raw_value, filter_config)
          end
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.DataLoader.Builder

      @doc """
      Parse raw filter values from form submission.
      Converts string keys to atoms and removes empty values.
      """
      @spec parse_filter_values(map(), list()) :: map()
      def parse_filter_values(raw_values, filter_configs) do
        Enum.reduce(raw_values, %{}, fn {field_name, raw_value}, acc ->
          field_atom =
            if is_binary(field_name), do: String.to_existing_atom(field_name), else: field_name

          filter_config = Enum.find(filter_configs, &(&1.name == field_atom))
          parsed = parse_single_filter(field_atom, raw_value, filter_config)

          if parsed != nil and parsed != "" do
            Map.put(acc, field_atom, parsed)
          else
            acc
          end
        end)
      end

      @doc """
      Parse a single filter value using its type module if available.
      """
      @spec parse_single_filter(atom(), any(), map() | nil) :: any()
      def parse_single_filter(_field_atom, raw_value, filter_config)
          when filter_config != nil and filter_config.type_module != nil do
        filter_config.type_module.parse_value(raw_value, filter_config)
      end

      def parse_single_filter(_field_atom, raw_value, _filter_config), do: raw_value

      defoverridable parse_filter_values: 2,
                     parse_single_filter: 3
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.FilterParser.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.FilterParser
end

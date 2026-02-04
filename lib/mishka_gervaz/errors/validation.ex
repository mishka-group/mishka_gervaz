defmodule MishkaGervaz.Errors.Validation do
  @moduledoc """
  Input validation errors (filters, sort, params).
  """
  use Splode.ErrorClass, class: :validation

  defmodule InvalidFilter do
    @moduledoc """
    Raised when a filter value is invalid.

    ## Fields

    - `:filter` - The filter name
    - `:value` - The invalid value
    - `:expected` - What was expected
    """
    use Splode.Error, fields: [:filter, :value, :expected], class: :validation

    def message(%{filter: filter, value: value, expected: nil}) do
      "Invalid filter value for #{inspect(filter)}: #{inspect(value)}"
    end

    def message(%{filter: filter, value: value, expected: expected}) do
      "Invalid filter value for #{inspect(filter)}: got #{inspect(value)}, expected #{expected}"
    end
  end

  defmodule InvalidSort do
    @moduledoc """
    Raised when a sort field or direction is invalid.

    ## Fields

    - `:field` - The field name
    - `:direction` - The invalid direction (if applicable)
    - `:reason` - The reason it's invalid
    """
    use Splode.Error, fields: [:field, :direction, :reason], class: :validation

    def message(%{field: field, direction: nil, reason: reason}) do
      "Invalid sort field #{inspect(field)}: #{reason}"
    end

    def message(%{field: field, direction: dir, reason: _reason}) do
      "Invalid sort direction #{inspect(dir)} for field #{inspect(field)}"
    end
  end

  defmodule InvalidParam do
    @moduledoc """
    Raised when a parameter is invalid.

    ## Fields

    - `:param` - The parameter name
    - `:value` - The invalid value
    - `:reason` - The reason it's invalid
    """
    use Splode.Error, fields: [:param, :value, :reason], class: :validation

    def message(%{param: param, value: value, reason: nil}) do
      "Invalid parameter #{inspect(param)}: #{inspect(value)}"
    end

    def message(%{param: param, value: _value, reason: reason}) do
      "Invalid parameter #{inspect(param)}: #{reason}"
    end
  end

  defmodule InvalidSelection do
    @moduledoc """
    Raised when row selection is invalid.

    ## Fields

    - `:reason` - The reason the selection is invalid
    - `:count` - Number of selected items (if applicable)
    """
    use Splode.Error, fields: [:reason, :count], class: :validation

    def message(%{reason: reason, count: nil}) do
      "Invalid selection: #{reason}"
    end

    def message(%{reason: reason, count: count}) do
      "Invalid selection (#{count} items): #{reason}"
    end
  end
end

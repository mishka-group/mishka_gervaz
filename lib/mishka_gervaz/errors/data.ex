defmodule MishkaGervaz.Errors.Data do
  @moduledoc """
  Data-related errors (loading, querying, fetching).
  """
  use Splode.ErrorClass, class: :data

  defmodule LoadFailed do
    @moduledoc """
    Raised when data loading fails.

    ## Fields

    - `:resource` - The resource module that failed to load
    - `:reason` - The reason for the failure
    - `:page` - Optional page number that failed
    """
    use Splode.Error, fields: [:resource, :reason, :page], class: :data

    def message(%{resource: resource, reason: reason, page: nil}) do
      "Failed to load #{inspect(resource)}: #{format_reason(reason)}"
    end

    def message(%{resource: resource, reason: reason, page: page}) do
      "Failed to load page #{page} of #{inspect(resource)}: #{format_reason(reason)}"
    end

    defp format_reason(reason) when is_binary(reason), do: reason
    defp format_reason(reason), do: inspect(reason)
  end

  defmodule QueryFailed do
    @moduledoc """
    Raised when a query fails to execute.

    ## Fields

    - `:resource` - The resource being queried
    - `:action` - The action that was being executed
    - `:reason` - The reason for the failure
    """
    use Splode.Error, fields: [:resource, :action, :reason], class: :data

    def message(%{resource: resource, action: action, reason: reason}) do
      "Query failed for #{inspect(resource)}.#{action}: #{inspect(reason)}"
    end
  end

  defmodule NotFound do
    @moduledoc """
    Raised when a record is not found.

    ## Fields

    - `:resource` - The resource type
    - `:id` - The ID that was not found
    """
    use Splode.Error, fields: [:resource, :id], class: :data

    def message(%{resource: resource, id: id}) do
      "#{inspect(resource)} with id #{inspect(id)} not found"
    end
  end

  defmodule StreamError do
    @moduledoc """
    Raised when a LiveView stream operation fails.

    ## Fields

    - `:stream_name` - The name of the stream
    - `:operation` - The operation that failed (:insert, :delete, :reset)
    - `:reason` - The reason for the failure
    """
    use Splode.Error, fields: [:stream_name, :operation, :reason], class: :data

    def message(%{stream_name: name, operation: op, reason: reason}) do
      "Stream #{inspect(name)} #{op} failed: #{inspect(reason)}"
    end
  end
end

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
end

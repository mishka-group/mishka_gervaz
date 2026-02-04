defmodule MishkaGervaz.Errors.Action do
  @moduledoc """
  Action execution errors (destroy, update, bulk operations).
  """
  use Splode.ErrorClass, class: :action

  defmodule Failed do
    @moduledoc """
    Raised when an action fails to execute.

    ## Fields

    - `:resource` - The resource module
    - `:action` - The action name
    - `:reason` - The reason for the failure
    - `:record_id` - Optional ID of the record
    """
    use Splode.Error, fields: [:resource, :action, :reason, :record_id], class: :action

    def message(%{resource: resource, action: action, reason: reason, record_id: nil}) do
      "Action #{action} failed on #{inspect(resource)}: #{format_reason(reason)}"
    end

    def message(%{resource: resource, action: action, reason: reason, record_id: id}) do
      "Action #{action} failed on #{inspect(resource)} (id: #{id}): #{format_reason(reason)}"
    end

    defp format_reason(%{errors: errors}) when is_list(errors) do
      Enum.map_join(errors, ", ", &format_single_error/1)
    end

    defp format_reason(reason) when is_binary(reason), do: reason
    defp format_reason(reason), do: inspect(reason)

    defp format_single_error(%{message: msg}), do: msg
    defp format_single_error(error), do: inspect(error)
  end

  defmodule Unauthorized do
    @moduledoc """
    Raised when user is not authorized to perform an action.

    ## Fields

    - `:resource` - The resource module
    - `:action` - The action attempted
    - `:actor` - Optional actor info
    """
    use Splode.Error, fields: [:resource, :action, :actor], class: :action

    def message(%{resource: resource, action: action, actor: nil}) do
      "Unauthorized to perform #{action} on #{inspect(resource)}"
    end

    def message(%{resource: resource, action: action, actor: actor}) do
      "#{inspect(actor)} is unauthorized to perform #{action} on #{inspect(resource)}"
    end
  end

  defmodule BulkFailed do
    @moduledoc """
    Raised when a bulk action fails.

    ## Fields

    - `:resource` - The resource module
    - `:action` - The bulk action name
    - `:total` - Total records attempted
    - `:failed` - Number of failures
    - `:errors` - List of individual errors
    """
    use Splode.Error, fields: [:resource, :action, :total, :failed, :errors], class: :action

    def message(%{resource: resource, action: action, total: total, failed: failed}) do
      "Bulk #{action} on #{inspect(resource)}: #{failed}/#{total} failed"
    end
  end

  defmodule HookFailed do
    @moduledoc """
    Raised when a lifecycle hook fails.

    ## Fields

    - `:hook` - The hook name (:before_delete, :after_delete, etc.)
    - `:reason` - The reason for the failure
    """
    use Splode.Error, fields: [:hook, :reason], class: :action

    def message(%{hook: hook, reason: reason}) do
      "Hook #{hook} failed: #{inspect(reason)}"
    end
  end
end

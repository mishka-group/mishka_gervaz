defmodule MishkaGervaz.Errors.Action do
  @moduledoc """
  Action execution errors.
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
end

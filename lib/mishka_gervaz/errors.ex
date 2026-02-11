defmodule MishkaGervaz.Errors do
  @moduledoc """
  Splode-based error handling for MishkaGervaz.

  ## Error Classes

  - `:data` - Data loading, query, and fetch errors
  - `:action` - Action execution errors (destroy, update, etc.)
  - `:config` - Runtime configuration errors
  - `:validation` - Input validation errors

  ## Usage

      # Raise an error
      raise MishkaGervaz.Errors.Data.LoadFailed, resource: MyResource, reason: :timeout

      # Create error without raising
      error = MishkaGervaz.Errors.Data.LoadFailed.exception(resource: MyResource, reason: :timeout)

      # Convert to Splode error
      MishkaGervaz.Errors.to_error(error)

      # Get error class
      MishkaGervaz.Errors.class(error)  # => :data

      # Format error for flash message
      MishkaGervaz.Errors.format_flash_message(error)
  """

  use Splode,
    error_classes: [
      data: MishkaGervaz.Errors.Data,
      action: MishkaGervaz.Errors.Action,
      config: MishkaGervaz.Errors.Config,
      validation: MishkaGervaz.Errors.Validation
    ],
    unknown_error: MishkaGervaz.Errors.Unknown

  @doc """
  Formats an error into a human-readable flash message.

  Handles MishkaGervaz errors, Ash errors, and generic errors.

  ## Examples

      iex> error = MishkaGervaz.Errors.Action.Failed.exception(action: :archive, reason: "forbidden")
      iex> MishkaGervaz.Errors.format_flash_message(error)
      "Archive failed: forbidden"

      iex> error = MishkaGervaz.Errors.Action.BulkFailed.exception(action: :delete, total: 10, failed: 3)
      iex> MishkaGervaz.Errors.format_flash_message(error)
      "Delete failed: 3 of 10 records failed"
  """
  @spec format_flash_message(Exception.t() | map()) :: String.t()
  def format_flash_message(%__MODULE__.Action.Failed{action: action, reason: reason}) do
    action_name = humanize_action(action)
    "#{action_name} failed: #{format_reason(reason)}"
  end

  def format_flash_message(%__MODULE__.Action.BulkFailed{
        action: action,
        total: total,
        failed: failed
      }) do
    action_name = humanize_action(action)
    "#{action_name} failed: #{failed} of #{total} records failed"
  end

  def format_flash_message(%__MODULE__.Action.Unauthorized{action: action}) do
    action_name = humanize_action(action)
    "#{action_name} failed: unauthorized"
  end

  def format_flash_message(%__MODULE__.Data.LoadFailed{reason: reason}) do
    "Failed to load data: #{format_reason(reason)}"
  end

  def format_flash_message(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    messages = errors |> Enum.map(&extract_error_message/1) |> Enum.take(3)
    "Validation failed: #{Enum.join(messages, ", ")}"
  end

  def format_flash_message(%{message: message}) when is_binary(message), do: message
  def format_flash_message(error) when is_binary(error), do: error
  def format_flash_message(error), do: "An error occurred: #{inspect(error)}"

  @doc """
  Extracts a human-readable message from various error formats.

  ## Examples

      iex> MishkaGervaz.Errors.extract_error_message(%{message: "Invalid email"})
      "Invalid email"

      iex> MishkaGervaz.Errors.extract_error_message(%{field: :email, message: "is invalid"})
      "email: is invalid"
  """
  @spec extract_error_message(map() | String.t() | any()) :: String.t()
  def extract_error_message(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    errors |> Enum.map(&extract_error_message/1) |> Enum.join(", ")
  end

  def extract_error_message(%{message: message}) when is_binary(message), do: message
  def extract_error_message(%{field: field, message: message}), do: "#{field}: #{message}"
  def extract_error_message(error) when is_binary(error), do: error
  def extract_error_message(error), do: inspect(error)

  defp humanize_action(action) when is_atom(action) do
    action |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp humanize_action(action) when is_binary(action), do: String.capitalize(action)
  defp humanize_action(_), do: "Action"

  defp format_reason({:bulk_action_failed, _status, errors}) when is_list(errors) do
    error_count = length(errors)

    if error_count == 1 do
      extract_error_message(hd(errors))
    else
      "#{error_count} errors occurred"
    end
  end

  defp format_reason(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    errors |> Enum.map(&extract_error_message/1) |> Enum.take(3) |> Enum.join(", ")
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end

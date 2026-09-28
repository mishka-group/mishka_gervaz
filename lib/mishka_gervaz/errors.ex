defmodule MishkaGervaz.Errors do
  @moduledoc """
  Splode-based error handling for MishkaGervaz.

  ## Error Classes

  - `:data`   - Data loading, query, and fetch errors
  - `:action` - Action execution errors (destroy, update, etc.)

  ## Usage

      # Raise an error
      raise MishkaGervaz.Errors.Data.LoadFailed, resource: MyResource, reason: :timeout

      # Create error without raising
      error = MishkaGervaz.Errors.Data.LoadFailed.exception(resource: MyResource, reason: :timeout)

      # Convert any value into a Splode error (unrecognized values become `Errors.Unknown`)
      MishkaGervaz.Errors.to_error(error)

      # Format error for flash message
      MishkaGervaz.Errors.format_flash_message(error)
  """

  use Splode,
    error_classes: [
      data: MishkaGervaz.Errors.Data,
      action: MishkaGervaz.Errors.Action
    ],
    unknown_error: MishkaGervaz.Errors.Unknown

  @doc """
  Formats an error into a human-readable flash message.

  Handles MishkaGervaz errors, Ash errors, and generic errors.

  ## Examples

      iex> error = MishkaGervaz.Errors.Action.Failed.exception(action: :archive, reason: "forbidden")
      iex> MishkaGervaz.Errors.format_flash_message(error)
      "Archive failed: forbidden"
  """
  @spec format_flash_message(any()) :: String.t()
  def format_flash_message(%__MODULE__.Action.Failed{action: action, reason: reason}) do
    "#{humanize_action(action)} failed: #{format_reason(reason)}"
  end

  def format_flash_message(%__MODULE__.Data.LoadFailed{reason: reason}) do
    "Failed to load data: #{format_reason(reason)}"
  end

  def format_flash_message(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    "Validation failed: #{format_ash_errors(errors, 3)}"
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
      "Email is invalid"

      iex> MishkaGervaz.Errors.extract_error_message(%{field: :tag_id, message: "That tag is archived."})
      "That tag is archived."

      iex> MishkaGervaz.Errors.extract_error_message(%{field: :title, message: "must be at least %{min}", vars: [min: 3]})
      "Title must be at least 3"

  A message that starts with a capital letter is a whole sentence and is returned as written; any
  other message follows its field's name, with `_id` dropped and underscores as spaces. `%{key}`
  placeholders are filled from the error's `:vars`.
  """
  @spec extract_error_message(any()) :: String.t()
  def extract_error_message(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    format_ash_errors(errors, :all)
  end

  def extract_error_message(%{field: field, message: message} = error) when is_binary(message) do
    message
    |> interpolate(Map.get(error, :vars))
    |> with_field(field)
  end

  def extract_error_message(%{message: message}) when is_binary(message), do: message
  def extract_error_message(error) when is_binary(error), do: error
  def extract_error_message(error), do: inspect(error)

  defp interpolate(message, vars) when is_list(vars) or is_map(vars) do
    Enum.reduce(vars, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp interpolate(message, _vars), do: message

  defp with_field(message, nil), do: message

  defp with_field(message, field) do
    if sentence?(message), do: message, else: "#{humanize_field(field)} #{message}"
  end

  defp sentence?(message) do
    case String.first(message) do
      nil -> false
      first -> first != String.downcase(first)
    end
  end

  defp humanize_field(field) do
    field
    |> to_string()
    |> String.replace_suffix("_id", "")
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_action(nil), do: "Action"

  defp humanize_action(action) when is_atom(action) do
    action |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp humanize_action(action) when is_binary(action), do: String.capitalize(action)
  defp humanize_action(_), do: "Action"

  defp format_reason({:bulk_action_failed, _status, errors}) when is_list(errors) do
    case errors do
      [single] -> extract_error_message(single)
      list -> "#{length(list)} errors occurred"
    end
  end

  defp format_reason(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    format_ash_errors(errors, 3)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp format_ash_errors(errors, take) do
    errors
    |> Enum.map(&extract_error_message/1)
    |> maybe_take(take)
    |> Enum.join(", ")
  end

  defp maybe_take(list, :all), do: list
  defp maybe_take(list, n) when is_integer(n), do: Enum.take(list, n)
end

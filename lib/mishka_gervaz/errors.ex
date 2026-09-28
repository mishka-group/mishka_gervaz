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

  ## Translation

  Every word these functions return goes through the Gettext backend
  `MishkaGervaz.Messages.gettext_backend/0` names, in the locale of the calling process:

  - MishkaGervaz's own words and templates in the `"mishka_gervaz"` domain.
  - An error's own message, such as Ash's `"is required"`, in the `"errors"` domain, with
    `dngettext` when its vars hold an integer `:count`. Its `%{key}` placeholders are filled from
    the error's vars after it is translated.
  - A field's name from the label the resource declares for it: its form field's `ui` label, else
    its table column's label. A field with neither is named by its humanized name in the
    `"mishka_gervaz"` domain.

  A message whose last character ends a sentence (`.` `!` `?` `…` `؟` `۔` `。` and the like, before
  any closing quote or bracket) is shown as written. Any other message is joined to its field's name
  through the `"%{field} %{message}"` template.

  A reason that is not a validation error is worded too: `:not_found`, and an
  `Ash.Error.Query.NotFound` with no primary key, as `"This record is no longer here."`; an
  `Ash.Error.Forbidden` by its policy's `custom_message`, else as `"You are not allowed to do
  this."`; any other exception by its own message.
  """

  use Splode,
    error_classes: [
      data: MishkaGervaz.Errors.Data,
      action: MishkaGervaz.Errors.Action
    ],
    unknown_error: MishkaGervaz.Errors.Unknown

  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers, only: [resolve_label: 1, resolve_ui_label: 1]

  alias MishkaGervaz.Resource.Info.Form, as: FormInfo
  alias MishkaGervaz.Resource.Info.Table, as: TableInfo

  @placeholder ~r/%\{([^}]*)\}/
  @sentence_end ~r/[.!?…؟۔。！？｡।॥။።។།‼⁇⁈⁉։][\s"'”’»)\]」』〉》]*\z/u

  @doc """
  Formats an error into a human-readable flash message.

  Handles MishkaGervaz errors, Ash errors, and generic errors. `resource` names the fields of an
  error that has no resource of its own; an `Action.Failed` or `Data.LoadFailed` uses its own
  `:resource` when `resource` is `nil`.

  An `Action.Failed` names its action by its `:label` (a string or a zero-arity function), else by
  its humanized `:action`.

  ## Examples

      iex> error = MishkaGervaz.Errors.Action.Failed.exception(action: :archive, reason: "forbidden")
      iex> MishkaGervaz.Errors.format_flash_message(error)
      "Archive failed: forbidden"

      iex> error = MishkaGervaz.Errors.Action.Failed.exception(action: :archive, label: "Delete", reason: "forbidden")
      iex> MishkaGervaz.Errors.format_flash_message(error)
      "Delete failed: forbidden"
  """
  @spec format_flash_message(any(), module() | nil) :: String.t()
  def format_flash_message(error, resource \\ nil)

  def format_flash_message(%__MODULE__.Action.Failed{} = error, resource) do
    dgettext("mishka_gervaz", "%{action} failed: %{reason}",
      action: action_word(error),
      reason: format_reason(error.reason, resource || error.resource)
    )
  end

  def format_flash_message(%__MODULE__.Data.LoadFailed{} = error, resource) do
    dgettext("mishka_gervaz", "Failed to load data: %{reason}",
      reason: format_reason(error.reason, resource || error.resource)
    )
  end

  def format_flash_message(%Ash.Error.Invalid{errors: errors}, resource) when is_list(errors) do
    dgettext("mishka_gervaz", "Validation failed: %{errors}",
      errors: format_ash_errors(errors, 3, resource)
    )
  end

  def format_flash_message(%{message: message} = error, resource) when is_binary(message),
    do: extract_error_message(error, resource)

  def format_flash_message(error, resource) when is_exception(error),
    do: extract_error_message(error, resource)

  def format_flash_message(error, _resource) when is_binary(error), do: error

  def format_flash_message(error, _resource) do
    dgettext("mishka_gervaz", "An error occurred: %{error}", error: inspect(error))
  end

  @doc """
  Extracts a human-readable message from various error formats.

  `resource` is the resource whose declared labels name the error's field. An Ash error AshPhoenix
  can show on a form (`AshPhoenix.FormData.Error`) is read the way the form reads it; one the form
  shows on no field is read by its own message. An error class holding several errors, such as
  `Ash.Error.Invalid`, joins the message of each, a repeated message once.

  ## Examples

      iex> MishkaGervaz.Errors.extract_error_message(%{message: "Invalid email"})
      "Invalid email"

      iex> MishkaGervaz.Errors.extract_error_message(%{field: :email, message: "is invalid"})
      "Email is invalid"

      iex> MishkaGervaz.Errors.extract_error_message(%{field: :tag_id, message: "That tag is archived."})
      "That tag is archived."

      iex> MishkaGervaz.Errors.extract_error_message(%{field: :title, message: "must be at least %{min}", vars: [min: 3]})
      "Title must be at least 3"
  """
  @spec extract_error_message(any(), module() | nil) :: String.t()
  def extract_error_message(error, resource \\ nil)

  def extract_error_message(%{errors: errors} = error, resource)
      when is_exception(error) and is_list(errors) do
    format_ash_errors(errors, :all, resource)
  end

  def extract_error_message(error, resource) do
    case form_errors(error) do
      [] ->
        own_message(error, resource)

      form_errors ->
        form_errors
        |> Enum.map(fn {field, message, vars} ->
          field_message(message, vars, field, resource)
        end)
        |> Enum.uniq()
        |> Enum.join(list_separator())
    end
  end

  defp form_errors(error) do
    case AshPhoenix.FormData.Error.impl_for(error) do
      nil -> []
      impl -> error |> impl.to_form_error() |> List.wrap()
    end
  end

  defp own_message(%{class: :forbidden} = error, _resource) when is_exception(error) do
    case Map.get(error, :custom_message) do
      message when is_binary(message) -> translate_error(message, Map.get(error, :vars))
      _none -> dgettext("mishka_gervaz", "You are not allowed to do this.")
    end
  end

  defp own_message(%Ash.Error.Query.NotFound{}, _resource), do: not_found()

  defp own_message(%{field: field, message: message} = error, resource)
       when is_binary(message) do
    field_message(message, Map.get(error, :vars), field, resource)
  end

  defp own_message(%{message: message} = error, _resource) when is_binary(message),
    do: translate_error(message, Map.get(error, :vars))

  defp own_message(error, _resource) when is_exception(error),
    do: translate_error(Exception.message(error), [])

  defp own_message(error, _resource) when is_binary(error), do: error
  defp own_message(error, _resource), do: inspect(error)

  defp not_found, do: dgettext("mishka_gervaz", "This record is no longer here.")

  @doc """
  Translates an error's own message in the `"errors"` domain and fills its `%{key}` placeholders
  from `vars`.

  Uses `dngettext` when `vars` holds an integer `:count`. A list var is joined with `", "`, and a
  value `String.Chars` cannot print is inspected. A message with a `%{key}` placeholder `vars` does
  not fill is returned as written.

  ## Examples

      iex> MishkaGervaz.Errors.translate_error("must be at least %{min}", min: 3)
      "must be at least 3"
  """
  @spec translate_error(String.t(), keyword() | map() | nil) :: String.t()
  def translate_error(message, vars) when is_binary(message) do
    bindings = bindings(vars)

    cond do
      unfilled_placeholder?(message, bindings) ->
        message

      is_integer(bindings[:count]) ->
        Gettext.dngettext(backend(), "errors", message, message, bindings.count, bindings)

      true ->
        Gettext.dgettext(backend(), "errors", message, bindings)
    end
  end

  defp unfilled_placeholder?(message, bindings) do
    bound = MapSet.new(bindings, fn {key, _value} -> to_string(key) end)

    @placeholder
    |> Regex.scan(message, capture: :all_but_first)
    |> Enum.any?(fn [key] -> not MapSet.member?(bound, key) end)
  end

  @doc """
  An error message about `field`, as a person reads it.

  `message` is translated with `translate_error/2`. A translated message that ends a sentence is
  returned as written; any other is joined to the field's name through the `"%{field} %{message}"`
  template. `field` is named by the label `resource` declares for it, else by its humanized name.
  A `nil` field, or AshPhoenix's `:_form` for the whole form, returns the message alone.
  """
  @spec field_message(
          String.t() | nil,
          keyword() | map() | nil,
          atom() | String.t() | nil,
          module() | nil
        ) ::
          String.t()
  def field_message(message, vars, field, resource) do
    (message || dgettext_noop("errors", "is invalid"))
    |> translate_error(vars)
    |> with_field(field, resource)
  end

  defp with_field(message, field, _resource) when field in [nil, :_form], do: message

  defp with_field(message, field, resource) do
    if sentence?(message) do
      message
    else
      dgettext("mishka_gervaz", "%{field} %{message}",
        field: field_name(resource, field),
        message: message
      )
    end
  end

  defp sentence?(message), do: Regex.match?(@sentence_end, message)

  defp field_name(resource, field) do
    declared_field_label(resource, field) || humanized_field(field)
  end

  defp declared_field_label(resource, field)
       when is_atom(resource) and not is_nil(resource) and is_atom(field) do
    if Spark.Dsl.is?(resource, Ash.Resource) do
      resolve_ui_label(FormInfo.field(resource, field)) ||
        column_label(TableInfo.column(resource, field))
    end
  end

  defp declared_field_label(_resource, _field), do: nil

  defp column_label(nil), do: nil
  defp column_label(column), do: resolve_label(column.label) || resolve_ui_label(column)

  defp humanized_field(field) do
    words =
      field
      |> to_string()
      |> String.replace_suffix("_id", "")
      |> String.replace("_", " ")
      |> String.capitalize()

    Gettext.dgettext(backend(), "mishka_gervaz", words)
  end

  defp action_word(%{label: label, action: action}) do
    resolve_label(label) || humanized_action(action)
  end

  defp humanized_action(action) when is_atom(action) and not is_nil(action) do
    words = action |> to_string() |> String.replace("_", " ") |> String.capitalize()
    Gettext.dgettext(backend(), "mishka_gervaz", words)
  end

  defp humanized_action(action) when is_binary(action) and action != "" do
    Gettext.dgettext(backend(), "mishka_gervaz", String.capitalize(action))
  end

  defp humanized_action(_action), do: dgettext("mishka_gervaz", "Action")

  defp format_reason({:bulk_action_failed, _status, [single]}, resource),
    do: extract_error_message(single, resource)

  defp format_reason({:bulk_action_failed, _status, errors}, _resource) when is_list(errors) do
    count = length(errors)
    dngettext("mishka_gervaz", "%{count} error occurred", "%{count} errors occurred", count)
  end

  defp format_reason(%{errors: errors} = reason, resource)
       when is_exception(reason) and is_list(errors) do
    format_ash_errors(errors, 3, resource)
  end

  defp format_reason(:not_found, _resource), do: not_found()

  defp format_reason(reason, resource) when is_exception(reason),
    do: extract_error_message(reason, resource)

  defp format_reason(reason, _resource) when is_binary(reason), do: reason
  defp format_reason(reason, _resource), do: inspect(reason)

  defp format_ash_errors(errors, take, resource) do
    errors
    |> Enum.map(&extract_error_message(&1, resource))
    |> Enum.uniq()
    |> maybe_take(take)
    |> Enum.join(list_separator())
  end

  defp maybe_take(list, :all), do: list
  defp maybe_take(list, n) when is_integer(n), do: Enum.take(list, n)

  defp list_separator do
    gettext_comment("Joins the messages of several errors in one line.")
    dpgettext("mishka_gervaz", "list separator", ", ")
  end

  defp bindings(nil), do: %{}

  defp bindings(vars) when is_list(vars) or is_map(vars) do
    Map.new(vars, fn {key, value} -> {key, printable(value)} end)
  end

  defp bindings(_vars), do: %{}

  defp printable(value) when is_binary(value) or is_number(value), do: value
  defp printable(%Regex{} = value), do: Regex.source(value)
  defp printable(value) when is_list(value), do: Enum.map_join(value, ", ", &printable/1)

  defp printable(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: inspect(value)
  end

  defp backend, do: MishkaGervaz.Messages.gettext_backend()
end

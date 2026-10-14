defmodule MishkaGervaz.Form.Types.Field.Select do
  @moduledoc """
  Single-select dropdown field type. Trims string values on sanitize.

  ## Example

      field :status, :select do
        options [{"Draft", :draft}, {"Published", :published}]
        include_nil "Any"
      end

  ## Blank choice

  A select draws an empty choice ahead of its options according to the field:

    * `ui placeholder` set - the empty choice is labelled with it, required or not
    * `required true`, or a `default` set - no empty choice
    * otherwise - an empty choice labelled "Select..."

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use MishkaGervaz.Messages
  import MishkaGervaz.Helpers, only: [resolve_label: 1]

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: String.trim(value)
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :select}

  @doc """
  The label of the empty choice a form select draws ahead of its options, or `nil` when it draws
  none.

  Takes the field map (`ui`, `required` and `default` are read from it) and returns the `ui`
  placeholder when one is set, `nil` for a required field or one with a default, and the
  translated "Select..." for any other.
  """
  @spec prompt(map()) :: String.t() | nil
  def prompt(field) do
    cond do
      placeholder = placeholder(field) -> placeholder
      Map.get(field, :required) == true -> nil
      not is_nil(Map.get(field, :default)) -> nil
      true -> dgettext("mishka_gervaz", "Select...")
    end
  end

  defp placeholder(%{ui: %{placeholder: placeholder}}) when not is_nil(placeholder),
    do: resolve_label(placeholder)

  defp placeholder(_field), do: nil
end

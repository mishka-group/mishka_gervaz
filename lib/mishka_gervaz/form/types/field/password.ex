defmodule MishkaGervaz.Form.Types.Field.Password do
  @moduledoc """
  Password input field type.

  Renders as a text input with `type="password"` for masked entry. Sanitize
  trims surrounding whitespace; values are otherwise passed through
  unchanged so trailing/leading characters that matter for hashing aren't
  silently stripped. A value longer than the field's `max_length` is refused in words, as a
  `:text` field's is (`MishkaGervaz.Form.Types.Field.Text.within_length/2`).

  ## Example

      field :password, :password do
        required true
        ui do label "Password" end
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, config), do: MishkaGervaz.Form.Types.Field.Text.within_length(value, config)

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: String.trim(value)
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :password}
end

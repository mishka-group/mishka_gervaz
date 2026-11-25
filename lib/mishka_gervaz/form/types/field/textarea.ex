defmodule MishkaGervaz.Form.Types.Field.Textarea do
  @moduledoc """
  Multi-line text input field type. Pass-through sanitization (preserves newlines and markup).

  A `max_length`, its own or its attribute's, is drawn as the textarea's `maxlength`, and a longer
  value that still reaches the form is refused in words, as a `:text` field's is
  (`MishkaGervaz.Form.Types.Field.Text.within_length/2`).

  ## Example

      field :body, :textarea do
        ui do
          rows 8
          placeholder "Write the post…"
        end
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
  def default_ui, do: %{type: :textarea}
end

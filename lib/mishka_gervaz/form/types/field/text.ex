defmodule MishkaGervaz.Form.Types.Field.Text do
  @moduledoc """
  Default text input field type. Strips HTML tags and trims whitespace on sanitize.

  ## Example

      field :title, :text do
        required true

        ui do
          label fn -> dgettext("mishka_gervaz", "Title") end
          placeholder "Post title"
        end
      end

  ## Text direction

  The input follows what is typed (`dir="auto"`). A field whose value is always written left to
  right, such as a slug, host, token or hex colour, says so with `ui do extra %{dir: "ltr"} end`.

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value) do
    value |> MishkaGervaz.Helpers.strip_tags() |> String.trim()
  end

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :text}
end

defmodule MishkaGervaz.Form.Types.Field.Text do
  @moduledoc """
  Default text input field type. Trims whitespace on sanitize and keeps the rest as typed.

  A value that holds an HTML tag, such as `<b>Ann</b>`, is refused rather than changed: the field
  keeps what was typed and shows "Name must be plain text, without HTML tags", and a save writes
  nothing. A bare `<` or `>`, as in `a < b`, is text and is taken. A field that takes markup is a
  `:textarea`.

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
  use MishkaGervaz.Messages

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def validate(value, _config), do: plain_text(value)

  @doc """
  `{:ok, value}` when `value` holds no HTML tag, as `MishkaGervaz.Helpers.strip_tags/1` finds them,
  or is not a string; otherwise the error a field shows for it.

  ## Examples

      iex> MishkaGervaz.Form.Types.Field.Text.plain_text("Tom & Jerry, a < b")
      {:ok, "Tom & Jerry, a < b"}

      iex> MishkaGervaz.Form.Types.Field.Text.plain_text("<b>Ann</b>")
      {:error, "must be plain text, without HTML tags"}
  """
  @spec plain_text(term()) :: {:ok, term()} | {:error, String.t()}
  def plain_text(value) when is_binary(value) do
    case MishkaGervaz.Helpers.strip_tags(value) do
      ^value -> {:ok, value}
      _stripped -> {:error, dgettext_noop("errors", "must be plain text, without HTML tags")}
    end
  end

  def plain_text(value), do: {:ok, value}

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: String.trim(value)

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :text}
end

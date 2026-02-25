defmodule MishkaGervaz.Form.Types.Field.Combobox do
  @moduledoc """
  Combobox field type: text input with dropdown suggestions.

  Combines free text entry with pre-loaded option suggestions.
  Users can type any value or select from the suggestion list.

  Options are resolved once at form initialization (not on every render),
  making it efficient for database-backed suggestion lists.

  ## Example

      field :language, :combobox do
        options fn ->
          case Ecto.Adapters.SQL.query(Repo, "SELECT DISTINCT language FROM posts") do
            {:ok, %{rows: rows}} -> Enum.map(rows, fn [lang] -> {String.upcase(lang), lang} end)
            _ -> []
          end
        end
      end
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
    value |> String.replace(~r/<[^>]*>/, "") |> String.trim()
  end

  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :combobox}
end

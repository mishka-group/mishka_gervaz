defmodule MishkaGervaz.Form.Types.Field.MultiSelect do
  @moduledoc """
  Multi-select field type, for an `{:array, :string}` or `{:array, :atom}` attribute or argument.

  The form draws one checkbox per option, all named `form[<field>][]`, so a save sends the ticked
  values as a list, and an empty list when nothing is ticked.

  ## Example

      field :roles, :multi_select do
        options [{"Admin", :admin}, {"Editor", :editor}]
      end

  See `MishkaGervaz.Form.Behaviours.FieldType` and `MishkaGervaz.Form.Types.Field`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :multi_select}
end

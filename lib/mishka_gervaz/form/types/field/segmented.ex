defmodule MishkaGervaz.Form.Types.Field.Segmented do
  @moduledoc """
  One choice drawn as a segmented control: the options side by side in one bar, the chosen one
  raised.

  Each segment is a radio input named `form[<field>]`. Options take the shapes
  `MishkaGervaz.Form.Types.Field.ChoiceCards` takes; an option's `:description` is a smaller line
  under its label and its `:icon` sits before the label. Suited to two to four short options.

  ## Example

      field :billing, :segmented do
        options [{"Monthly", :monthly}, {"Yearly", :yearly}]
      end

  The UI adapter draws it with `segmented_control/1`.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config), do: assigns

  @impl true
  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config) when is_binary(value), do: String.trim(value)
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :segmented}
end

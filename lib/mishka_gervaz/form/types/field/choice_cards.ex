defmodule MishkaGervaz.Form.Types.Field.ChoiceCards do
  @moduledoc """
  One choice drawn as a card per option, for an attribute that holds one of a few values.

  Each card is a radio input named `form[<field>]` with the option's label, and under it an
  optional second line and an icon. An option is `{label, value}`, or a keyword list or map with
  `:label`, `:value`, `:description` and `:icon` (see `MishkaGervaz.Helpers.choice_options/1`).
  `options` may also be `fn -> options end` or `fn state -> options end`, read each time the field
  is drawn.

  ## Example

      field :kind, :choice_cards do
        options [
          [label: "One-time", value: :one_time, description: "Pay once, keep it", icon: "hero-bolt"],
          [label: "Subscription", value: :subscription, description: "Billed every period"]
        ]
      end

  The UI adapter draws it with `choice_cards/1`. See `MishkaGervaz.Form.Types.Field.Segmented` for
  the same choice as a segmented control.
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
  def default_ui, do: %{type: :choice_cards}
end

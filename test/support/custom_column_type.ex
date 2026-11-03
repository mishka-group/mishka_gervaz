defmodule MishkaGervaz.Test.CustomColumnType do
  @moduledoc """
  Custom column type for testing custom type support.
  """
  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(nil, _column, _record, ui) do
    ui.cell_empty(%{__changed__: %{}})
  end

  def render(value, _column, _record, ui) do
    ui.cell_text(%{
      __changed__: %{},
      text: "CUSTOM: #{value}",
      class: "custom-column-type"
    })
  end
end

defmodule MishkaGervaz.Test.CustomFilterType do
  @moduledoc """
  Custom filter type for testing custom type support.
  """
  @behaviour MishkaGervaz.Table.Behaviours.FilterType
  use Phoenix.Component

  @impl true
  def render_input(assigns, _filter, _ui) do
    ~H"""
    <input type="text" class="custom-filter" placeholder="Custom filter" />
    """
  end

  @impl true
  def parse_value(value, _filter), do: value

  @impl true
  def build_query(query, _field, _value), do: query
end

defmodule MishkaGervaz.Test.CustomActionType do
  @moduledoc """
  Custom action type for testing custom type support.
  """
  @behaviour MishkaGervaz.Table.Behaviours.ActionType
  use Phoenix.Component

  @impl true
  def render(assigns, _action, _record, _ui, _target) do
    ~H"""
    <button class="custom-action">Custom Action</button>
    """
  end
end

defmodule MishkaGervaz.Test.ColorFieldType do
  @moduledoc """
  Custom form field type for testing that the Standard template draws a field through its type
  module's `render/2`, and that its `validate/2` refuses a value that is not a hex colour.
  """
  @behaviour MishkaGervaz.Form.Behaviours.FieldType
  use Phoenix.Component

  @impl true
  def validate(value, _config) when value in [nil, ""], do: {:ok, value}
  def validate("#" <> _hex = value, _config), do: {:ok, value}
  def validate(_value, _config), do: {:error, "must be a hex colour"}

  @impl true
  def render(assigns, _config) do
    ~H"""
    <input type="color" data-role="color-picker" name={@name} id={@id} value={@value} />
    """
  end
end

defmodule MishkaGervaz.Test.Web.KeptRows do
  @moduledoc """
  A table template drawn from the rows the table keeps loaded (`keep_loaded_records`), as a
  template that groups its rows is drawn, since a LiveView stream holds no groups.

  Its root is `data-template="kept_rows"`, after the template switcher, and each row is a
  `data-role="kept-row"` item with the row's id in `data-id` and its title as its text, in the
  order the table keeps them. The table's pagination is drawn under them.
  """

  use MishkaGervaz.Table.Behaviours.Template

  alias MishkaGervaz.Table.Templates.Shared

  @impl true
  def name, do: :kept_rows

  @impl true
  def label, do: "Kept rows"

  @impl true
  def icon, do: "hero-queue-list"

  @impl true
  def description, do: "The rows the table keeps loaded"

  @impl true
  def features, do: [:paginate]

  @impl true
  def default_options, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@static.id} data-template="kept_rows">
      <Shared.render_template_switcher
        switchable_templates={@static.switchable_templates}
        current_template={@state.template}
        ui_adapter={@static.ui_adapter}
        myself={@myself}
      />
      <ul>
        <li :for={row <- @state.loaded_records} data-role="kept-row" data-id={row.id}>
          {row.title}
        </li>
      </ul>
      <Shared.render_pagination static={@static} state={@state} myself={@myself} />
    </div>
    """
  end

  @impl true
  def render_item(assigns) do
    ~H"""
    <li data-role="kept-row" data-id={@record.id}>{@record.title}</li>
    """
  end
end

defmodule MishkaGervaz.Table.Types.Column.Site do
  @moduledoc """
  Site column type - the site (tenant) a row of a multi-tenant table belongs to.

  A table that reads across tenants, as a master's read of every site does, shows rows of many
  sites, and this column says whose each row is. Left `visible`, the column is drawn only while
  the table reads across tenants (`MishkaGervaz.Table.Templates.Shared.across_tenants?/1`), so a
  site's admin, and any table read under one tenant, never gets it. Read the site with the row
  for masters only, so the others pay no read for it:

      source do
        preload do
          master [:site]
        end
      end

      columns do
        column :site do
          source {:site, :name}

          ui do
            type :site
          end
        end
      end

  The value is the site's name, or the site itself when it has a `:name`; an empty cell for a row
  whose site was not read. It is drawn in a quiet monospace face through the UI adapter's
  `cell_text/1`.

  See `MishkaGervaz.Table.Types.Column` (registry),
  `MishkaGervaz.Table.Behaviours.ColumnType`, and
  `MishkaGervaz.Table.Entities.Column`.
  """

  @behaviour MishkaGervaz.Table.Behaviours.ColumnType
  use Phoenix.Component

  @impl true
  def render(%{name: name}, column, record, ui), do: render(name, column, record, ui)

  def render(name, _column, _record, ui) when is_binary(name) and name != "" do
    cell =
      ui.cell_text(%{
        __changed__: %{},
        text: name,
        class: "font-mono text-[11px] text-[#5c5a54]",
        dir: "auto"
      })

    assigns = %{cell: cell}

    ~H"""
    <span data-role="gervaz-site-cell">{@cell}</span>
    """
  end

  def render(_missing, _column, _record, ui), do: ui.cell_empty(%{__changed__: %{}})

  @impl true
  def cell_class(_column), do: nil
end

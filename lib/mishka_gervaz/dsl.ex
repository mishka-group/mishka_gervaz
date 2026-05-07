defmodule MishkaGervaz.Dsl do
  @moduledoc """
  DSL definitions for MishkaGervaz.

  This module assembles all MishkaGervaz DSL sections into a top-level
  `mishka_gervaz` section. Supports:

  - `table` - Admin list-view configuration (see `MishkaGervaz.Table.Dsl`)
  - `form`  - Create/edit form configuration (see `MishkaGervaz.Form.Dsl`)

  Both sections are siblings inside `mishka_gervaz do … end` and may be
  used independently or together on a single resource.

  ## Usage

  ```elixir
  defmodule MyApp.Resource do
    use Ash.Resource,
      extensions: [MishkaGervaz.Resource]

    mishka_gervaz do
      table do
        identity do
          route "/admin/resources"
        end

        columns do
          column :name, sortable: true
        end

        row_actions do
          action :edit, type: :link
        end
      end

      form do
        identity do
          name :resource_form
          route "/admin/resources"
        end

        fields do
          field :name, :text, required: true
        end
      end
    end
  end
  ```
  """

  @doc """
  Returns all DSL sections for MishkaGervaz.

  This is called by `MishkaGervaz.Resource` extension.
  """
  def sections do
    [mishka_gervaz_section()]
  end

  defp mishka_gervaz_section do
    %Spark.Dsl.Section{
      name: :mishka_gervaz,
      describe: "MishkaGervaz admin UI DSL configuration.",
      sections: [
        MishkaGervaz.Table.Dsl.section()
      ]
    }
  end
end

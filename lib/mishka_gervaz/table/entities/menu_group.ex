defmodule MishkaGervaz.Table.Entities.MenuGroup do
  @moduledoc """
  Entity struct for navigation menu group configuration.

  Used by `MishkaGervaz.Domain` extension.
  """

  @type t :: %__MODULE__{
          name: atom(),
          label: String.t() | nil,
          icon: String.t() | nil,
          position: integer() | nil,
          resources: [atom()],
          visible: boolean() | (map() -> boolean()),
          __spark_metadata__: map() | nil
        }

  defstruct [
    :name,
    label: nil,
    icon: nil,
    position: nil,
    resources: [],
    visible: true,
    __spark_metadata__: nil
  ]

  @opt_schema [
    name: [
      type: :atom,
      required: true,
      doc: "Menu group identifier."
    ],
    label: [
      type: :string,
      doc: "Display label. Defaults to humanized name."
    ],
    icon: [
      type: :string,
      doc: "Icon identifier for the menu group."
    ],
    position: [
      type: :integer,
      doc: "Sort order position."
    ],
    resources: [
      type: {:list, :atom},
      default: [],
      doc: "Resources to include in this menu group."
    ],
    visible: [
      type: {:or, [:boolean, {:fun, 1}]},
      default: true,
      doc: "Visibility. Can be boolean or `fn user -> boolean`."
    ]
  ]

  @doc false
  def opt_schema, do: @opt_schema

  @doc """
  Transform the menu group after DSL compilation.
  """
  def transform(%__MODULE__{} = menu_group) do
    menu_group = maybe_set_label(menu_group)
    {:ok, menu_group}
  end

  def transform(menu_group), do: {:ok, menu_group}

  defp maybe_set_label(%{label: nil, name: name} = menu_group) do
    label =
      name
      |> Atom.to_string()
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")

    %{menu_group | label: label}
  end

  defp maybe_set_label(menu_group), do: menu_group
end

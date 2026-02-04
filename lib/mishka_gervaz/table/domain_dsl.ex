defmodule MishkaGervaz.Table.DomainDsl do
  @moduledoc """
  Domain-level DSL sections for MishkaGervaz.

  This module defines the DSL structure used by `MishkaGervaz.Domain`
  for setting default table configuration at the domain level.

  Resources inherit these defaults via `MishkaGervaz.Resource`.
  """

  alias MishkaGervaz.Table.Dsl.{Defaults, Navigation}

  @doc """
  Returns the domain-level mishka_gervaz section.
  """
  def section do
    %Spark.Dsl.Section{
      name: :mishka_gervaz,
      describe: "MishkaGervaz domain configuration for shared table defaults.",
      top_level?: true,
      sections: [
        Defaults.section(),
        Navigation.section()
      ]
    }
  end

  @doc """
  Returns the list of domain sections for the extension.
  """
  def sections do
    [section()]
  end
end

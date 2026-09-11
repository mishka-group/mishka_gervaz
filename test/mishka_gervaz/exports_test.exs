defmodule MishkaGervaz.ExportsTest do
  @moduledoc """
  `function_exported?/3` answers about a module that is already in memory.

  Under Elixir's interactive code loading, which is what `mix phx.server` uses, a module that
  compiled fine and has simply not been reached yet is not in memory, so the answer is `false`. As a
  capability check that means "no, this type module has no `parse_params/2`" in development and
  "yes" in a release.

  It was not hypothetical. `MishkaGervaz.Form.Types.Field.Nested` is named in the type registry as
  data and never called by name, so nothing loaded it, `custom_parse_params?` was false, and every
  nested field's values went to the changeset uncast — a `:toggle` sub-field storing the string
  `"true"` and every reader that asked `== true` saying no.

  Not async: it purges a module to reproduce the state the answer depends on.
  """
  use ExUnit.Case, async: false

  alias MishkaGervaz.Helpers

  @unloaded MishkaGervaz.Form.Types.Field.KeyList

  setup do
    :code.purge(@unloaded)
    :code.delete(@unloaded)
    on_exit(fn -> Code.ensure_loaded(@unloaded) end)
    :ok
  end

  test "says yes about a module that is compiled but not loaded yet" do
    refute :erlang.module_loaded(@unloaded),
           "the purge has to have worked for this to mean anything"

    refute function_exported?(@unloaded, :parse_params, 2), "which is the bug itself"

    assert Helpers.exports?(@unloaded, :parse_params, 2)
  end

  test "and the ordinary answers are still the ordinary answers" do
    assert Helpers.exports?(Enum, :map, 2)
    refute Helpers.exports?(Enum, :map, 97)
    refute Helpers.exports?(NoSuchModule.Anywhere, :map, 2)
    refute Helpers.exports?(nil, :map, 2)
    refute Helpers.exports?("Enum", :map, 2)
  end
end

defmodule MishkaGervaz.Errors.Unknown do
  @moduledoc """
  Unknown/unclassified errors.
  """
  use Splode.Error, fields: [:error], class: :unknown

  def message(%{error: error}) do
    "Unknown error: #{inspect(error)}"
  end
end

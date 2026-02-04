defmodule MishkaGervaz.Table.Entities.EmptyState do
  @moduledoc """
  Entity struct for empty state configuration.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          icon: String.t() | nil,
          action_label: String.t() | nil,
          action_path: String.t() | nil,
          action_icon: String.t() | nil,
          __spark_metadata__: map() | nil
        }

  defstruct message: "No records found",
            icon: nil,
            action_label: nil,
            action_path: nil,
            action_icon: nil,
            __spark_metadata__: nil
end

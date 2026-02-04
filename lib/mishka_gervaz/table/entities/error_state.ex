defmodule MishkaGervaz.Table.Entities.ErrorState do
  @moduledoc """
  Entity struct for error state configuration.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          icon: String.t() | nil,
          retry_label: String.t(),
          __spark_metadata__: map() | nil
        }

  defstruct message: "Error loading data",
            icon: nil,
            retry_label: "Retry",
            __spark_metadata__: nil
end

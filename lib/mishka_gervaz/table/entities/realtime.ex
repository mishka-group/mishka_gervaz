defmodule MishkaGervaz.Table.Entities.Realtime do
  @moduledoc """
  Entity struct for realtime configuration.
  """

  @type t :: %__MODULE__{
          enabled: boolean(),
          pubsub: module() | nil,
          prefix: String.t() | nil,
          visible: (any(), any() -> boolean()) | nil,
          __spark_metadata__: map() | nil
        }

  defstruct enabled: true,
            pubsub: nil,
            prefix: nil,
            visible: nil,
            __spark_metadata__: nil
end

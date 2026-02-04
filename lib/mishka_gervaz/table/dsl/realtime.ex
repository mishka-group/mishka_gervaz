defmodule MishkaGervaz.Table.Dsl.Realtime do
  @moduledoc """
  Realtime entity DSL definition for table configuration.

  Defines PubSub configuration for live updates.
  Supports both inline and block syntax:

      # Inline
      realtime prefix: "site"

      # Block
      realtime do
        prefix "site"
        pubsub MyApp.Endpoint
      end
  """

  @schema [
    enabled: [
      type: :boolean,
      default: true,
      doc: "Enable realtime updates."
    ],
    pubsub: [
      type: {:behaviour, Phoenix.PubSub},
      doc: "PubSub module."
    ],
    prefix: [
      type: :string,
      doc: "Topic prefix (e.g., \"component\" -> \"component:created\")."
    ],
    visible: [
      type: {:fun, 2},
      doc: "Function `fn record, user -> boolean` for filtering updates."
    ]
  ]

  @doc false
  def schema, do: @schema

  @doc """
  Returns the realtime entity definition.
  """
  def entity do
    %Spark.Dsl.Entity{
      name: :realtime,
      describe: "PubSub configuration for live updates.",
      target: MishkaGervaz.Table.Entities.Realtime,
      schema: @schema,
      singleton_entity_keys: [:realtime]
    }
  end
end

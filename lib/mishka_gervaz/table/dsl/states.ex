defmodule MishkaGervaz.Table.Dsl.States do
  @moduledoc """
  Empty and Error state entities DSL definition for table configuration.

  Supports both inline and block syntax:

      # Inline
      empty_state message: "No sites found", icon: "hero-globe-alt"
      error_state message: "Failed to load"

      # Block
      empty_state do
        message "No sites found"
        icon "hero-globe-alt"
      end
  """

  alias MishkaGervaz.Table.Entities.{EmptyState, ErrorState}

  @empty_state_schema [
    message: [
      type: :string,
      default: "No records found",
      doc: "Empty state message."
    ],
    icon: [
      type: :string,
      doc: "Icon identifier."
    ],
    action_label: [
      type: :string,
      doc: "Call-to-action button label."
    ],
    action_path: [
      type: :string,
      doc: "Call-to-action button path."
    ],
    action_icon: [
      type: :string,
      doc: "Call-to-action button icon."
    ]
  ]

  @doc """
  Returns the empty_state entity definition.
  """
  def empty_state_entity do
    %Spark.Dsl.Entity{
      name: :empty_state,
      describe: "Empty state configuration.",
      target: EmptyState,
      schema: @empty_state_schema,
      singleton_entity_keys: [:empty_state]
    }
  end

  @error_state_schema [
    message: [
      type: :string,
      default: "Error loading data",
      doc: "Error message."
    ],
    icon: [
      type: :string,
      doc: "Icon identifier."
    ],
    retry_label: [
      type: :string,
      default: "Retry",
      doc: "Retry button label."
    ]
  ]

  @doc """
  Returns the error_state entity definition.
  """
  def error_state_entity do
    %Spark.Dsl.Entity{
      name: :error_state,
      describe: "Error state configuration.",
      target: ErrorState,
      schema: @error_state_schema,
      singleton_entity_keys: [:error_state]
    }
  end
end

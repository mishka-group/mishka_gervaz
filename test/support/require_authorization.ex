defmodule MishkaGervaz.Test.RequireAuthorization do
  @moduledoc """
  Validation shaped like the authorization validations a host app puts on its actions: it stands
  aside when authorization is off, and otherwise only lets an `:admin` actor through.

  Use it to assert that a caller runs an action with authorization on.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(_subject, _opts, %{authorize?: false}), do: :ok

  def validate(_subject, _opts, %{actor: %{role: :admin}}), do: :ok

  def validate(_subject, _opts, _context),
    do: {:error, message: "This action requires an admin actor."}

  @impl true
  def supports(_opts), do: [Ash.Changeset, Ash.ActionInput, Ash.Query]
end

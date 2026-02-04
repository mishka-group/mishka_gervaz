defmodule MishkaGervaz.Table.Defaults do
  @moduledoc """
  Default functions for table configuration.

  These functions are used by transformers and must be named (not anonymous)
  so they can be properly escaped by Spark's DSL macros.
  """

  @doc """
  Default master check - checks if the user's site_id is nil.
  """
  @spec default_master_check(map() | struct()) :: boolean()
  def default_master_check(user) do
    default_master_check(user, :site_id)
  end

  @doc """
  Master check with custom field.
  """
  @spec default_master_check(map() | struct(), atom()) :: boolean()
  def default_master_check(user, field) do
    is_nil(Map.get(user, field))
  end

  @doc """
  Default visibility function for realtime updates.
  Checks if user can see the record based on tenant field.
  """
  @spec default_visibility(map() | struct(), map() | struct()) :: boolean()
  def default_visibility(record, user) do
    default_visibility(record, user, :site_id)
  end

  @doc """
  Visibility check with custom field.
  """
  @spec default_visibility(map() | struct(), map() | struct(), atom()) :: boolean()
  def default_visibility(record, user, field) do
    user_tenant = Map.get(user, field)
    record_tenant = Map.get(record, field)

    is_nil(user_tenant) or record_tenant in [nil, user_tenant]
  end
end

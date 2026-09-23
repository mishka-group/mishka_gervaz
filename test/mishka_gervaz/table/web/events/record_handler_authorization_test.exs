defmodule MishkaGervaz.Table.Web.Events.RecordHandlerAuthorizationTest do
  @moduledoc """
  Every write the table makes runs with authorization on.

  `Ash.destroy(record, action: ...)` resolves the domain's `authorize?` default only after the
  changeset has been built, so an archiving destroy — the soft clause AshArchival puts every archive
  through — handed the action's validations `authorize?: false` and every validation that stands
  aside on that was skipped. The handler says `authorize?: true` itself instead.
  """
  # async: false to prevent ETS race conditions with shared test resources
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.Events.BulkActionHandler
  alias MishkaGervaz.Table.Web.Events.RecordHandler.Default, as: RecordHandler
  alias MishkaGervaz.Table.Web.State
  alias MishkaGervaz.Test.Resources.AuthorizedWriteResource, as: Resource

  require Ash.Query

  defp admin, do: %{id: "admin-1", site_id: nil, role: :admin}
  defp member, do: %{id: "member-1", site_id: nil, role: :user}

  defp state(user, master_user?) do
    "record-handler-authorization"
    |> State.init(Resource, user)
    |> State.update(master_user?: master_user?)
  end

  defp record!, do: Ash.create!(Resource, %{title: "Item"}, authorize?: false)

  defp archived!(record) do
    {:ok, archived} =
      Ash.destroy(record, action: :master_destroy, authorize?: false, return_destroyed?: true)

    archived
  end

  defp reload(record) do
    Ash.get(Resource, record.id, action: :master_get_archived, authorize?: false)
  end

  # The bulk archive as the table runs it: the handler's own opts, over one row.
  defp bulk_destroy(user, record) do
    {opts, type} = BulkActionHandler.build_ash_bulk_opts(state(user, true), :master_destroy)

    Resource
    |> Ash.Query.filter(id == ^record.id)
    |> BulkActionHandler.execute_bulk_by_type(opts, type)
  end

  setup do
    on_exit(fn ->
      try do
        MishkaGervaz.Test.Ets.stop(Resource)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "a row action" do
    test "refuses a delete the action's validation would refuse" do
      record = record!()

      assert {:error, _} = RecordHandler.delete_record(state(member(), true), record)
      assert {:ok, %{archived_at: nil}} = reload(record)
    end

    test "refuses a destroy_record with an explicit action" do
      record = record!()

      assert {:error, _} =
               RecordHandler.destroy_record(state(member(), true), record, :master_destroy)

      assert {:ok, %{archived_at: nil}} = reload(record)
    end

    test "refuses a permanent delete" do
      record = record!() |> archived!()

      assert {:error, _} = RecordHandler.permanent_destroy_record(state(member(), true), record)
      assert {:ok, _} = reload(record)
    end

    test "refuses a restore" do
      record = record!() |> archived!()

      assert {:error, _} = RecordHandler.unarchive_record(state(member(), true), record)
      assert {:ok, %{archived_at: archived_at}} = reload(record)
      refute is_nil(archived_at)
    end

    test "refuses an update_record with an explicit action" do
      record = record!() |> archived!()

      assert {:error, _} =
               RecordHandler.update_record(state(member(), true), record, :master_unarchive)

      assert {:ok, %{archived_at: archived_at}} = reload(record)
      refute is_nil(archived_at)
    end

    test "lets an admin delete, restore and delete permanently" do
      state = state(admin(), true)
      record = record!()

      assert {:ok, _} = RecordHandler.delete_record(state, record)
      assert {:ok, %{archived_at: archived_at} = archived} = reload(record)
      refute is_nil(archived_at)

      assert {:ok, _} = RecordHandler.unarchive_record(state, archived)
      assert {:ok, %{archived_at: nil} = active} = reload(record)

      assert {:ok, _} = RecordHandler.destroy_record(state, active, :master_destroy)
      assert {:ok, archived} = reload(record)

      assert {:ok, _} = RecordHandler.permanent_destroy_record(state, archived)
      assert {:error, _} = reload(record)
    end
  end

  # The bulk half runs through `Ash.Actions.Update.Bulk.run`, which is not the code path a row
  # action takes — so it is driven here rather than asserted as a keyword list.
  describe "a bulk action" do
    test "runs with authorization on" do
      {opts, _type} = BulkActionHandler.build_ash_bulk_opts(state(admin(), true), :master_destroy)

      assert opts[:authorize?] == true
    end

    test "refuses an archive the action's validation would refuse" do
      record = record!()

      refute bulk_destroy(member(), record).status == :success
      assert {:ok, %{archived_at: nil}} = reload(record)
    end

    test "archives for an admin" do
      record = record!()

      assert bulk_destroy(admin(), record).status == :success
      assert {:ok, %{archived_at: archived_at}} = reload(record)
      refute is_nil(archived_at)
    end
  end

  describe "an internal caller" do
    test "still writes with authorize?: false, as seeds and boot code do" do
      record = record!()

      assert {:ok, _} =
               Ash.destroy(record,
                 action: :master_destroy,
                 authorize?: false,
                 return_destroyed?: true
               )

      assert {:ok, %{archived_at: archived_at} = archived} = reload(record)
      refute is_nil(archived_at)

      assert {:ok, _} = Ash.update(archived, action: :master_unarchive, authorize?: false)
      assert {:ok, %{archived_at: nil}} = reload(record)
    end
  end
end

defmodule MishkaGervaz.Table.Transformers.ArchiveMergeTest do
  @moduledoc """
  Verifies the archive merge rules between resource and domain `archive` blocks.

  Rules under test (mirrors the design discussed for archive merge):

    1. Resource without `AshArchival.Resource` ⇒ archive is `nil`, regardless
       of domain defaults.
    2. Resource with `AshArchival.Resource` and no archive block ⇒ inherits
       fully from the domain.
    3. Resource with `AshArchival.Resource` and `archive do enabled false end`
       ⇒ archive is `nil` (test-only opt-out).
    4. Per-key merge ⇒ resource keys win, missing keys fall back to domain.
    5. Atom action value ⇒ used for both master and tenant requests.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Resource.Info.Table, as: TableInfo

  alias MishkaGervaz.Test.Resources.{
    ArchiveMergeNoExt,
    ArchiveMergeInheritDomain,
    ArchiveMergeEnabledFalse,
    ArchiveMergePartial,
    ArchiveMergeAtomAction
  }

  describe "rule 1 — resource without AshArchival.Resource" do
    test "archive is nil even though the domain provides defaults" do
      assert get_in(TableInfo.config(ArchiveMergeNoExt), [:source, :archive]) == nil
    end

    test "archive_enabled?/1 returns false" do
      refute TableInfo.archive_enabled?(ArchiveMergeNoExt)
    end
  end

  describe "rule 2 — resource with AshArchival inherits from the domain" do
    test "enabled true and uses domain action defaults" do
      archive = get_in(TableInfo.config(ArchiveMergeInheritDomain), [:source, :archive])
      assert archive.enabled == true
      assert archive.actions.read == {:master_archived, :archived}
      assert archive.actions.get == {:master_get_archived, :get_archived}
      assert archive.actions.restore == {:master_unarchive, :unarchive}
      assert archive.actions.destroy == {:master_permanent_destroy, :permanent_destroy}
    end

    test "default flags resolve correctly" do
      archive = get_in(TableInfo.config(ArchiveMergeInheritDomain), [:source, :archive])
      assert archive.restricted == false
      assert archive.visible == true
    end
  end

  describe "rule 3 — enabled false suppresses archive entirely" do
    test "archive resolves to nil" do
      assert get_in(TableInfo.config(ArchiveMergeEnabledFalse), [:source, :archive]) == nil
    end

    test "archive_enabled?/1 returns false" do
      refute TableInfo.archive_enabled?(ArchiveMergeEnabledFalse)
    end
  end

  describe "rule 4 — per-key merge" do
    test "resource overrides win" do
      archive = get_in(TableInfo.config(ArchiveMergePartial), [:source, :archive])
      assert archive.restricted == true
      assert archive.actions.read == {:resource_master_archived, :resource_archived}
    end

    test "missing keys fall back to the domain" do
      archive = get_in(TableInfo.config(ArchiveMergePartial), [:source, :archive])
      assert archive.actions.get == {:master_get_archived, :get_archived}
      assert archive.actions.restore == {:master_unarchive, :unarchive}
      assert archive.actions.destroy == {:master_permanent_destroy, :permanent_destroy}
    end
  end

  describe "rule 5 — atom action value applies to both master and tenant" do
    test "stored as a plain atom (resolved per-request via archive_action_for/3)" do
      archive = get_in(TableInfo.config(ArchiveMergeAtomAction), [:source, :archive])
      assert archive.actions.read == :shared_archived
    end

    test "archive_action_for resolves the atom for master users" do
      assert TableInfo.archive_action_for(ArchiveMergeAtomAction, :read, true) ==
               :shared_archived
    end

    test "archive_action_for resolves the atom for tenant users" do
      assert TableInfo.archive_action_for(ArchiveMergeAtomAction, :read, false) ==
               :shared_archived
    end
  end

  describe "archive_action_for tuple resolution" do
    test "returns the master action for master users" do
      assert TableInfo.archive_action_for(ArchiveMergeInheritDomain, :read, true) ==
               :master_archived
    end

    test "returns the tenant action for tenant users" do
      assert TableInfo.archive_action_for(ArchiveMergeInheritDomain, :read, false) ==
               :archived
    end
  end
end

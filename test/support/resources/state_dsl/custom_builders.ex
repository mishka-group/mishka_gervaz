defmodule MishkaGervaz.Test.StateDsl.CustomColumnBuilder do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.ColumnBuilder

  def build(config, resource) do
    columns = super(config, resource)
    Enum.reverse(columns)
  end
end

defmodule MishkaGervaz.Test.StateDsl.CustomFilterBuilder do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.FilterBuilder

  def build(config, resource, current_user) do
    super(config, resource, current_user)
  end

  def build_initial_values(filters) do
    values = super(filters)
    Map.put(values, :__custom_filter_marker__, true)
  end
end

defmodule MishkaGervaz.Test.StateDsl.CustomActionBuilder do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.ActionBuilder

  def build_row_actions(config) do
    super(config)
  end

  def build_bulk_actions(config) do
    super(config)
  end

  def build_hooks(config) do
    hooks = super(config)
    Map.put(hooks, :__custom_hooks_marker__, true)
  end
end

defmodule MishkaGervaz.Test.StateDsl.CustomPresentation do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.Presentation

  def resolve_template(_config) do
    MishkaGervaz.Table.Templates.Table
  end

  def get_template_options(config) do
    opts = super(config)
    Keyword.put(opts, :__custom_presentation_marker__, true)
  end
end

defmodule MishkaGervaz.Test.StateDsl.CustomUrlSync do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.UrlSync

  def apply_url_state(state, url_state) do
    state = super(state, url_state)
    %{state | base_path: state.base_path || "/custom-url-sync"}
  end

  def bidirectional?(_state) do
    true
  end
end

defmodule MishkaGervaz.Test.StateDsl.CustomAccess do
  @moduledoc false
  use MishkaGervaz.Table.Web.State.Access

  def master_user?(%{role: :superadmin}), do: true
  def master_user?(user), do: super(user)

  def can_modify_record?(true, _user, _record), do: true

  def can_modify_record?(false, user, record) do
    cond do
      Map.get(user, :can_modify_all, false) -> true
      is_struct(record) -> super(false, user, record)
      true -> check_tenant_for_map(user, record)
    end
  end

  defp check_tenant_for_map(user, record) do
    user_tenant = Map.get(user, :site_id)
    record_tenant = Map.get(record, :site_id)
    user_tenant != nil and record_tenant == user_tenant
  end
end

defmodule MishkaGervaz.Test.StateDsl.CustomWholeState do
  @moduledoc false
  use MishkaGervaz.Table.Web.State

  def init(id, resource, current_user) do
    state = default_init(id, resource, current_user)
    %{state | base_path: "/whole-state-override"}
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.CustomFieldBuilder do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.FieldBuilder

  def build(config, resource) do
    fields = super(config, resource)
    Enum.map(fields, &Map.put(&1, :__custom_field_marker__, true))
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.CustomGroupBuilder do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.GroupBuilder

  def build(config, resource) do
    groups = super(config, resource)
    Enum.map(groups, &Map.put(&1, :__custom_group_marker__, true))
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.CustomStepBuilder do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.StepBuilder

  def build(config, resource) do
    steps = super(config, resource)
    Enum.map(steps, &Map.put(&1, :__custom_step_marker__, true))
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.CustomPresentation do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.Presentation

  def resolve_template(_config) do
    MishkaGervaz.Form.Templates.Standard
  end

  def get_features(config) do
    features = super(config)
    [:__custom_presentation_marker__ | features]
  end
end

defmodule MishkaGervaz.Test.FormStateDsl.CustomAccess do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.Access

  def master_user?(%{role: :superadmin}), do: true
  def master_user?(user), do: super(user)

  def get_tenant(%{tenant_override: t}) when not is_nil(t), do: t
  def get_tenant(user), do: super(user)
end

defmodule MishkaGervaz.Test.FormStateDsl.CustomWholeState do
  @moduledoc false
  use MishkaGervaz.Form.Web.State

  def init(id, resource, current_user) do
    state = default_init(id, resource, current_user)
    %{state | defaults: %{__whole_state_override__: true}}
  end
end

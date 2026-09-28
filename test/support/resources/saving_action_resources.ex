defmodule MishkaGervaz.Test.Resources.PickerRegion do
  @moduledoc """
  The top of a three-level picker chain: region, then workspace, then version.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:name]]
  end
end

defmodule MishkaGervaz.Test.Resources.PickerWorkspace do
  @moduledoc """
  A workspace of one `MishkaGervaz.Test.Resources.PickerRegion`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :region_id, :uuid, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:name, :region_id]]
  end
end

defmodule MishkaGervaz.Test.Resources.PickerVersion do
  @moduledoc """
  A version of one `MishkaGervaz.Test.Resources.PickerWorkspace`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :workspace_id, :uuid, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:name, :workspace_id]]
  end
end

defmodule MishkaGervaz.Test.Resources.PickerEntry do
  @moduledoc """
  A form whose pickers depend on each other: `:workspace_id` on `:region_id`, and the required
  `:version_id` on `:workspace_id`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  alias MishkaGervaz.Test.Resources.{PickerRegion, PickerVersion, PickerWorkspace}

  ets do
    private? false
  end

  mishka_gervaz do
    form do
      identity do
        name :picker_entry
        route "/admin/picker-entries"
      end

      source do
        actions do
          create :create
          update :update
          read :read
        end
      end

      fields do
        field :title, :text

        field :region_id, :relation do
          resource PickerRegion
          display_field :name
          mode :search
        end

        field :workspace_id, :relation do
          resource PickerWorkspace
          display_field :name
          mode :search
          depends_on :region_id

          load fn query, state ->
            Ash.Query.filter_input(query, %{region_id: Map.get(state.field_values, :region_id)})
          end
        end

        field :version_id, :relation do
          resource PickerVersion
          display_field :name
          mode :search
          required true
          depends_on :workspace_id

          load fn query, state ->
            Ash.Query.filter_input(query, %{
              workspace_id: Map.get(state.field_values, :workspace_id)
            })
          end
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
    attribute :region_id, :uuid, public?: true
    attribute :workspace_id, :uuid, public?: true
    attribute :version_id, :uuid, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :region_id, :workspace_id, :version_id]
    end

    update :update do
      primary? true
      accept [:title, :region_id, :workspace_id, :version_id]
    end
  end
end

defmodule MishkaGervaz.Test.Resources.RaisingCreate do
  @moduledoc """
  A create action whose change raises while the changeset is built.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  actions do
    defaults [:read, update: [:title]]

    create :create do
      accept [:title]
      change fn _changeset, _context -> raise "the change failed" end
    end
  end
end

defmodule MishkaGervaz.Test.Resources.CreateOnlyNote do
  @moduledoc """
  A form that only creates: it has no update action and closes `:update` with `access :update, false`.
  """
  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  mishka_gervaz do
    form do
      identity do
        name :create_only_note
        route "/admin/create-only-notes"
      end

      source do
        actions do
          create :create
          read :read
        end

        access :update, false
      end

      fields do
        field :body, :text
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :body, :string, public?: true
  end

  actions do
    defaults [:read, create: [:body]]
  end
end

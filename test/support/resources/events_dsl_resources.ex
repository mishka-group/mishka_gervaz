defmodule MishkaGervaz.Test.EventsDsl do
  @moduledoc """
  Test resources and handlers for Events DSL tests.
  """

  # Custom handler modules for testing
  defmodule CustomSanitizationHandler do
    use MishkaGervaz.Table.Web.Events.SanitizationHandler

    def sanitize(value) when is_binary(value) do
      # Custom: convert to uppercase
      value |> HtmlSanitizeEx.strip_tags() |> String.upcase()
    rescue
      _ -> value
    end

    def sanitize(value), do: value
  end

  defmodule CustomRecordHandler do
    use MishkaGervaz.Table.Web.Events.RecordHandler

    # Uses default implementation
  end

  defmodule CustomSelectionHandler do
    use MishkaGervaz.Table.Web.Events.SelectionHandler

    # Custom: limit selection to 5 items
    def toggle_select(state, id) do
      if MapSet.size(state.selected_ids) >= 5 do
        state
      else
        super(state, id)
      end
    end
  end

  defmodule CustomBulkActionHandler do
    use MishkaGervaz.Table.Web.Events.BulkActionHandler

    # Uses default implementation
  end

  defmodule CustomHookRunner do
    use MishkaGervaz.Table.Web.Events.HookRunner

    # Uses default implementation
  end

  defmodule CustomRelationFilterHandler do
    use MishkaGervaz.Table.Web.Events.RelationFilterHandler

    # Custom: track calls for testing
    def handle(action, params, state, socket) do
      Process.put(:custom_relation_filter_handler_called, true)
      Process.put(:custom_relation_filter_action, action)
      super(action, params, state, socket)
    end
  end

  defmodule CustomEventsModule do
    use MishkaGervaz.Table.Web.Events

    # Custom events module that uses custom handlers
  end

  # Test domain
  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource MishkaGervaz.Test.EventsDsl.CustomSanitizationResource
      resource MishkaGervaz.Test.EventsDsl.CustomRecordResource
      resource MishkaGervaz.Test.EventsDsl.CustomFullResource
      resource MishkaGervaz.Test.EventsDsl.CustomModuleResource
      resource MishkaGervaz.Test.EventsDsl.BasicResource
    end
  end

  # Resource with custom sanitization handler
  defmodule CustomSanitizationResource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.EventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :custom_sanitization_items
          route "/admin/custom-sanitization"
        end

        columns do
          column :name do
            sortable true
          end
        end

        events do
          sanitization(MishkaGervaz.Test.EventsDsl.CustomSanitizationHandler)
        end

        pagination page_size: 5, type: :numbered
      end
    end

    actions do
      defaults [:destroy, create: :*, update: :*]

      read :read do
        primary? true
        pagination offset?: true, countable: true
      end

      read :get
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end
  end

  # Resource with custom record handler
  defmodule CustomRecordResource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.EventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :custom_record_items
          route "/admin/custom-record"
        end

        columns do
          column :name do
            sortable true
          end
        end

        events do
          record(MishkaGervaz.Test.EventsDsl.CustomRecordHandler)
        end

        pagination page_size: 5, type: :numbered
      end
    end

    actions do
      defaults [:destroy, create: :*, update: :*]

      read :read do
        primary? true
        pagination offset?: true, countable: true
      end

      read :get
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end
  end

  # Resource with multiple custom sub-builders
  defmodule CustomFullResource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.EventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :custom_full_items
          route "/admin/custom-full"
        end

        columns do
          column :name do
            sortable true
          end
        end

        events do
          sanitization(MishkaGervaz.Test.EventsDsl.CustomSanitizationHandler)
          record(MishkaGervaz.Test.EventsDsl.CustomRecordHandler)
          selection(MishkaGervaz.Test.EventsDsl.CustomSelectionHandler)
          bulk_action(MishkaGervaz.Test.EventsDsl.CustomBulkActionHandler)
          hooks(MishkaGervaz.Test.EventsDsl.CustomHookRunner)
          relation_filter(MishkaGervaz.Test.EventsDsl.CustomRelationFilterHandler)
        end

        pagination page_size: 5, type: :numbered
      end
    end

    actions do
      defaults [:destroy, create: :*, update: :*]

      read :read do
        primary? true
        pagination offset?: true, countable: true
      end

      read :get
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end
  end

  # Resource with custom module (positional arg)
  defmodule CustomModuleResource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.EventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :custom_module_items
          route "/admin/custom-module"
        end

        columns do
          column :name do
            sortable true
          end
        end

        events(MishkaGervaz.Test.EventsDsl.CustomEventsModule)

        pagination page_size: 5, type: :numbered
      end
    end

    actions do
      defaults [:destroy, create: :*, update: :*]

      read :read do
        primary? true
        pagination offset?: true, countable: true
      end

      read :get
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end
  end

  # Resource without custom events
  defmodule BasicResource do
    use Ash.Resource,
      domain: MishkaGervaz.Test.EventsDsl.TestDomain,
      extensions: [MishkaGervaz.Resource],
      data_layer: Ash.DataLayer.Ets

    mishka_gervaz do
      table do
        identity do
          name :basic_items
          route "/admin/basic"
        end

        columns do
          column :name do
            sortable true
          end
        end

        pagination page_size: 5, type: :numbered
      end
    end

    actions do
      defaults [:destroy, create: :*, update: :*]

      read :read do
        primary? true
        pagination offset?: true, countable: true
      end

      read :get
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end
  end
end

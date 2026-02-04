defmodule MishkaGervaz.Test.VirtualFilter.Domain do
  @moduledoc false
  use Ash.Domain,
    extensions: [MishkaGervaz.Domain],
    validate_config_inclusion?: false

  mishka_gervaz do
    table do
      actor_key :current_user
      master_check fn user -> user && Map.get(user, :site_id) == nil end
      pagination type: :numbered, page_size: 10
    end
  end

  resources do
    resource MishkaGervaz.Test.VirtualFilter.TagResource
    resource MishkaGervaz.Test.VirtualFilter.ArticleResource
  end
end

defmodule MishkaGervaz.Test.VirtualFilter.TagResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.VirtualFilter.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read do
      primary? true
      pagination offset?: true, countable: true, required?: false
    end

    read :master_read do
      pagination offset?: true, countable: true, required?: false
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end
end

defmodule MishkaGervaz.Test.VirtualFilter.ArticleResource do
  @moduledoc false
  use Ash.Resource,
    domain: MishkaGervaz.Test.VirtualFilter.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  require Ash.Query

  mishka_gervaz do
    table do
      identity do
        name :vf_articles
        route "/admin/vf-articles"
      end

      columns do
        column :title do
          sortable true
        end

        column :category
        column :author_name
      end

      filters do
        # Baseline: standard text filter
        filter :search, :text do
          fields [:title]
        end

        # Test 1: Virtual select with apply — maps to category field
        filter :tag, :select do
          virtual true

          options [
            [value: "elixir", label: "Elixir"],
            [value: "phoenix", label: "Phoenix"],
            [value: "ash", label: "Ash"]
          ]

          apply fn query, value, _assigns ->
            Ash.Query.filter(query, category == ^value)
          end
        end

        # Test 2: Non-virtual select with custom apply (overrides type_module)
        filter :category, :select do
          options [
            [value: "tech", label: "Technology"],
            [value: "science", label: "Science"],
            [value: "arts", label: "Arts"]
          ]

          apply fn query, value, _assigns ->
            Ash.Query.filter(query, category == ^value)
          end
        end

        # Test 3: Virtual boolean with apply
        filter :has_author, :boolean do
          virtual true

          apply fn query, value, _assigns ->
            case value do
              true -> Ash.Query.filter(query, not is_nil(author_name))
              false -> Ash.Query.filter(query, is_nil(author_name))
              _ -> query
            end
          end
        end

        # Test 4: Relation filter with custom load function (sorts options)
        filter :tag_id, :relation do
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          display_field :name

          load fn query, _state ->
            Ash.Query.sort(query, name: :asc)
          end
        end

        # Test 5: Virtual relation with resource + load + apply
        filter :external_tag, :relation do
          virtual true
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          display_field :name
          mode :static

          load fn query, _state ->
            Ash.Query.sort(query, name: :desc)
          end

          apply fn query, value, _assigns ->
            Ash.Query.filter(query, category == ^value)
          end
        end

        # Test 6: Context-aware apply — uses context.path_params
        filter :path_scoped, :select do
          virtual true

          options [
            [value: "scoped", label: "Scoped"],
            [value: "unscoped", label: "Unscoped"]
          ]

          apply fn query, value, context ->
            case Map.get(context, :path_params) do
              %{workspace_version_id: wv_id} when is_binary(wv_id) ->
                Ash.Query.filter(query, category == ^wv_id)

              _ ->
                Ash.Query.filter(query, category == ^value)
            end
          end
        end

        # Test 7: Context-aware load — branches on master vs tenant
        filter :context_tag, :relation do
          virtual true
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          display_field :name
          mode :static

          load fn query, state ->
            if state.master_user? do
              Ash.Query.sort(query, name: :asc)
            else
              Ash.Query.sort(query, name: :desc)
            end
          end

          apply fn query, value, _context ->
            Ash.Query.filter(query, category == ^value)
          end
        end

        # Test 8: source + apply — apply should take precedence over source
        filter :source_override, :text do
          source :category

          apply fn query, value, _context ->
            Ash.Query.filter(query, title == ^value)
          end
        end

        # Test 9: display_field as 2-arity function
        filter :display_tag, :relation do
          virtual true
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          mode :static

          display_field fn record, state ->
            if state.master_user?,
              do: "Master: #{record.name}",
              else: record.name
          end
        end

        # Test 10: Relation filter with search mode + custom load
        filter :searchable_tag, :relation do
          virtual true
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          display_field :name
          mode :search
          search_field :name
          min_chars 1
          page_size 5

          load fn query, _state ->
            Ash.Query.sort(query, name: :asc)
          end

          apply fn query, value, _context ->
            Ash.Query.filter(query, tag_id == ^value)
          end
        end

        # ── depends_on & bridge pattern tests ──

        # Test 11: depends_on parent filter
        filter :region, :select do
          virtual true

          options [
            [value: "us", label: "USA"],
            [value: "eu", label: "Europe"]
          ]

          apply fn query, value, _context ->
            Ash.Query.filter(query, category == ^value)
          end
        end

        # Test 12: depends_on child filter — disabled until :region has value
        filter :city, :select do
          virtual true
          depends_on :region

          options [
            [value: "ny", label: "New York"],
            [value: "london", label: "London"]
          ]

          apply fn query, value, _context ->
            Ash.Query.filter(query, author_name == ^value)
          end

          ui do
            disabled_prompt "Select region first"
          end
        end

        # Test 13: Bridge filter — no-op apply, value consumed by another filter
        filter :bridge_tag, :relation do
          virtual true
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          display_field :name
          mode :static

          apply fn query, _value, _context -> query end
        end

        # Test 14: Consumes bridge_tag value from context.filter_values
        filter :bridge_consumer, :boolean do
          virtual true

          apply fn query, _value, context ->
            case Map.get(context.filter_values, :bridge_tag) do
              nil -> query
              tag_id -> Ash.Query.filter(query, category == ^tag_id)
            end
          end
        end

        # Test 15: Multi-select bridge — list value consumed by another filter
        filter :multi_bridge, :relation do
          virtual true
          resource MishkaGervaz.Test.VirtualFilter.TagResource
          display_field :name
          mode :static

          apply fn query, _value, _context -> query end
        end

        # Test 16: Consumes multi_bridge list from context.filter_values
        filter :multi_consumer, :boolean do
          virtual true

          apply fn query, _value, context ->
            case Map.get(context.filter_values, :multi_bridge) do
              ids when is_list(ids) and ids != [] ->
                Ash.Query.filter(query, category in ^ids)

              _ ->
                query
            end
          end
        end

        # Test 17: Chain invalidation — depends_on :city (region→city→district)
        filter :district, :select do
          virtual true
          depends_on :city

          options [
            [value: "manhattan", label: "Manhattan"],
            [value: "brooklyn", label: "Brooklyn"]
          ]

          apply fn query, value, _context ->
            Ash.Query.filter(query, author_name == ^value)
          end
        end

        # Test 18: Relation parent invalidation — depends_on :bridge_tag
        filter :tag_child, :boolean do
          virtual true
          depends_on :bridge_tag

          apply fn query, value, _context ->
            case value do
              true -> Ash.Query.filter(query, not is_nil(author_name))
              _ -> query
            end
          end
        end
      end

      pagination page_size: 10, type: :numbered
    end
  end

  actions do
    defaults [:destroy, create: :*, update: :*]

    read :read do
      primary? true
      pagination offset?: true, countable: true
    end

    read :master_read do
      pagination offset?: true, countable: true
    end

    read :tenant_read do
      pagination offset?: true, countable: true
    end

    read :get
    read :master_get
    read :tenant_get
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :category, :string, public?: true
    attribute :author_name, :string, public?: true
    attribute :tag_id, :uuid, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :tag, MishkaGervaz.Test.VirtualFilter.TagResource do
      source_attribute :tag_id
      allow_nil? true
      public? true
    end
  end
end

defmodule MishkaGervaz.Table.Web.DependsOnInvalidationTest do
  @moduledoc """
  Tests for `depends_on` invalidation — when a parent filter changes,
  child filters (and their cached relation state) are cleared.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Table.Web.{Events, State}
  alias MishkaGervaz.Helpers

  alias MishkaGervaz.Test.VirtualFilter.{
    TagResource,
    ArticleResource
  }

  defp master_user, do: %{id: "master-123", site_id: nil, role: :admin}

  defp clear_ets(resource) do
    try do
      Ash.DataLayer.Ets.stop(resource)
    rescue
      _ -> :ok
    end
  end

  defp create_socket(state, opts \\ []) do
    stream_name = state.static.stream_name

    base_assigns = %{
      __changed__: %{},
      table_state: state,
      flash: %{},
      live_action: :index
    }

    assigns =
      if Keyword.get(opts, :with_stream, false) do
        live_stream = %Phoenix.LiveView.LiveStream{
          name: stream_name,
          dom_id: fn item -> "#{stream_name}-#{item.id}" end,
          ref: make_ref(),
          inserts: [],
          deletes: [],
          reset?: false,
          consumable?: false
        }

        Map.put(base_assigns, :streams, %{stream_name => live_stream})
      else
        base_assigns
      end

    %Phoenix.LiveView.Socket{
      assigns: assigns,
      private: %{
        lifecycle: %{handle_event: [], after_render: []},
        assign_new: %{},
        changed: %{},
        connected?: true,
        live_temp: %{}
      },
      endpoint: MishkaGervazWeb.Endpoint,
      id: "test-socket",
      root_pid: self(),
      router: nil,
      view: nil
    }
  end

  defp init_loaded_state(resource, user, opts \\ []) do
    state = State.init("test-id", resource, user)

    updates =
      Keyword.merge(
        [
          loading: :loaded,
          has_initial_data?: true,
          page: 1,
          has_more?: false
        ],
        opts
      )

    State.update(state, updates)
  end

  setup do
    on_exit(fn ->
      clear_ets(TagResource)
      clear_ets(ArticleResource)
    end)

    :ok
  end

  # ── Helper Unit Tests ─────────────────────────────────────────────

  describe "invalidate_dependents/3 — helper unit tests" do
    test "no changes returns original values" do
      state = init_loaded_state(ArticleResource, master_user())

      filter_values = %{region: "us", city: "ny"}
      old_filter_values = %{region: "us", city: "ny"}

      {cleaned_fv, cleaned_rfs} =
        Helpers.invalidate_dependents(filter_values, old_filter_values, state)

      assert cleaned_fv == %{region: "us", city: "ny"}
      assert cleaned_rfs == %{}
    end

    test "parent change clears child from filter_values" do
      state = init_loaded_state(ArticleResource, master_user())

      old = %{region: "us", city: "ny"}
      new = %{region: "eu", city: "ny"}

      {cleaned_fv, _cleaned_rfs} =
        Helpers.invalidate_dependents(new, old, state)

      assert cleaned_fv == %{region: "eu"}
      refute Map.has_key?(cleaned_fv, :city)
    end

    test "parent change clears child from relation_filter_state" do
      state = init_loaded_state(ArticleResource, master_user())

      state = %{
        state
        | relation_filter_state: %{
            city: %{options: [{"New York", "ny"}], has_more?: false, page: 1}
          }
      }

      old = %{region: "us", city: "ny"}
      new = %{region: "eu", city: "ny"}

      {_cleaned_fv, cleaned_rfs} =
        Helpers.invalidate_dependents(new, old, state)

      refute Map.has_key?(cleaned_rfs, :city)
    end

    test "chain invalidation — region→city→district" do
      state = init_loaded_state(ArticleResource, master_user())

      old = %{region: "us", city: "ny", district: "manhattan"}
      new = %{region: "eu", city: "ny", district: "manhattan"}

      {cleaned_fv, _cleaned_rfs} =
        Helpers.invalidate_dependents(new, old, state)

      assert cleaned_fv == %{region: "eu"}
      refute Map.has_key?(cleaned_fv, :city)
      refute Map.has_key?(cleaned_fv, :district)
    end

    test "no dependents returns original values" do
      state = init_loaded_state(ArticleResource, master_user())

      old = %{search: "old"}
      new = %{search: "new"}

      {cleaned_fv, _cleaned_rfs} =
        Helpers.invalidate_dependents(new, old, state)

      # :search has no dependents, so nothing else is cleared
      assert cleaned_fv == %{search: "new"}
    end

    test "grandchild without grandparent change — only district cleared" do
      state = init_loaded_state(ArticleResource, master_user())

      old = %{region: "us", city: "ny", district: "manhattan"}
      new = %{region: "us", city: "london", district: "manhattan"}

      {cleaned_fv, _cleaned_rfs} =
        Helpers.invalidate_dependents(new, old, state)

      # region unchanged, city changed → district (depends on city) cleared
      assert cleaned_fv == %{region: "us", city: "london"}
      refute Map.has_key?(cleaned_fv, :district)
    end
  end

  # ── Filter Event Invalidation ─────────────────────────────────────

  describe "filter event — parent change clears child" do
    test "changing region clears city value" do
      Ash.create!(ArticleResource, %{title: "A", category: "eu"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny"}
        )

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle("filter", %{"region" => "eu"}, socket)

      updated_state = updated_socket.assigns.table_state
      assert updated_state.filter_values[:region] == "eu"
      refute Map.has_key?(updated_state.filter_values, :city)
    end

    test "changing region clears both city and district (chain)" do
      Ash.create!(ArticleResource, %{title: "A", category: "eu"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny", district: "manhattan"}
        )

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle("filter", %{"region" => "eu"}, socket)

      updated_state = updated_socket.assigns.table_state
      assert updated_state.filter_values[:region] == "eu"
      refute Map.has_key?(updated_state.filter_values, :city)
      refute Map.has_key?(updated_state.filter_values, :district)
    end

    test "changing region clears child relation_filter_state" do
      Ash.create!(ArticleResource, %{title: "A", category: "eu"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny"}
        )

      state = %{
        state
        | relation_filter_state: %{
            city: %{
              options: [{"NY", "ny"}],
              has_more?: false,
              page: 1,
              selected_options: [{"NY", "ny"}]
            }
          }
      }

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle("filter", %{"region" => "eu"}, socket)

      updated_state = updated_socket.assigns.table_state
      refute Map.has_key?(updated_state.relation_filter_state, :city)
    end

    test "parent unchanged preserves child" do
      Ash.create!(ArticleResource, %{title: "A", category: "us", author_name: "ny"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny"}
        )

      socket = create_socket(state)

      # Include city in params so form parsing retains it;
      # the filter handler only preserves existing values for :relation type filters
      {:noreply, updated_socket} =
        Events.handle("filter", %{"region" => "us", "city" => "ny", "search" => "A"}, socket)

      updated_state = updated_socket.assigns.table_state
      assert updated_state.filter_values[:region] == "us"
      assert updated_state.filter_values[:city] == "ny"
    end
  end

  # ── Remove Filter Invalidation ────────────────────────────────────

  describe "remove_filter event — clears dependents" do
    test "removing parent clears child" do
      Ash.create!(ArticleResource, %{title: "A", category: "us"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny"}
        )

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle("remove_filter", %{"name" => "region"}, socket)

      updated_state = updated_socket.assigns.table_state
      refute Map.has_key?(updated_state.filter_values, :region)
      refute Map.has_key?(updated_state.filter_values, :city)
    end

    test "removing parent clears entire chain" do
      Ash.create!(ArticleResource, %{title: "A", category: "us"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny", district: "manhattan"}
        )

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle("remove_filter", %{"name" => "region"}, socket)

      updated_state = updated_socket.assigns.table_state
      refute Map.has_key?(updated_state.filter_values, :region)
      refute Map.has_key?(updated_state.filter_values, :city)
      refute Map.has_key?(updated_state.filter_values, :district)
    end
  end

  # ── Relation Filter Invalidation ──────────────────────────────────

  describe "relation select — parent clears child" do
    test "selecting bridge_tag clears tag_child" do
      tag = Ash.create!(TagResource, %{name: "Tag1"})
      Ash.create!(ArticleResource, %{title: "A", category: "tech"})

      state =
        init_loaded_state(ArticleResource, master_user(), filter_values: %{tag_child: "true"})

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "relation_select",
          %{"filter" => "bridge_tag", "id" => tag.id, "label" => "Tag1"},
          socket
        )

      updated_state = updated_socket.assigns.table_state
      assert updated_state.filter_values[:bridge_tag] == tag.id
      refute Map.has_key?(updated_state.filter_values, :tag_child)
    end

    test "deselecting bridge_tag (toggle off) clears tag_child" do
      tag = Ash.create!(TagResource, %{name: "Tag1"})
      Ash.create!(ArticleResource, %{title: "A", category: "tech"})

      # bridge_tag already selected, tag_child has a value
      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{bridge_tag: tag.id, tag_child: "true"}
        )

      state = %{
        state
        | relation_filter_state: %{
            bridge_tag: %{
              options: [],
              has_more?: false,
              page: 1,
              selected_options: [{"Tag1", tag.id}],
              dropdown_open?: false
            }
          }
      }

      socket = create_socket(state)

      # Selecting the same value again deselects it
      {:noreply, updated_socket} =
        Events.handle(
          "relation_select",
          %{"filter" => "bridge_tag", "id" => tag.id, "label" => "Tag1"},
          socket
        )

      updated_state = updated_socket.assigns.table_state
      refute Map.has_key?(updated_state.filter_values, :bridge_tag)
      refute Map.has_key?(updated_state.filter_values, :tag_child)
    end
  end

  describe "relation toggle — parent clears child" do
    test "toggling multi_bridge clears dependent (multi_consumer depends indirectly)" do
      tag = Ash.create!(TagResource, %{name: "Toggle Tag"})
      Ash.create!(ArticleResource, %{title: "A", category: "tech"})

      # Start with no multi_bridge selected
      state = init_loaded_state(ArticleResource, master_user(), filter_values: %{})

      state = %{
        state
        | relation_filter_state: %{
            multi_bridge: %{
              options: [{tag.name, tag.id}],
              has_more?: false,
              page: 1,
              selected_options: [],
              dropdown_open?: true
            }
          }
      }

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "relation_toggle",
          %{"filter" => "multi_bridge", "id" => tag.id, "label" => tag.name},
          socket
        )

      updated_state = updated_socket.assigns.table_state
      # multi_bridge should now have the toggled value
      assert updated_state.filter_values[:multi_bridge] == [tag.id]
    end
  end

  describe "relation clear — parent clears child" do
    test "clearing bridge_tag clears tag_child" do
      tag = Ash.create!(TagResource, %{name: "Clear Tag"})
      Ash.create!(ArticleResource, %{title: "A", category: "tech"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{bridge_tag: tag.id, tag_child: "true"}
        )

      state = %{
        state
        | relation_filter_state: %{
            bridge_tag: %{
              options: [],
              has_more?: false,
              page: 1,
              selected_options: [{"Clear Tag", tag.id}],
              dropdown_open?: false
            }
          }
      }

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle(
          "relation_clear",
          %{"filter" => "bridge_tag"},
          socket
        )

      updated_state = updated_socket.assigns.table_state
      refute Map.has_key?(updated_state.filter_values, :bridge_tag)
      refute Map.has_key?(updated_state.filter_values, :tag_child)
    end
  end

  # ── Clear All Filters ─────────────────────────────────────────────

  describe "clear_filters — no double-processing" do
    test "clear_filters clears everything without errors" do
      Ash.create!(ArticleResource, %{title: "A", category: "us", author_name: "ny"})

      state =
        init_loaded_state(ArticleResource, master_user(),
          filter_values: %{region: "us", city: "ny", district: "manhattan"}
        )

      state = %{
        state
        | relation_filter_state: %{
            city: %{options: [{"NY", "ny"}], has_more?: false, page: 1, selected_options: []}
          }
      }

      socket = create_socket(state)

      {:noreply, updated_socket} =
        Events.handle("clear_filters", %{}, socket)

      updated_state = updated_socket.assigns.table_state
      assert updated_state.filter_values == %{}
      assert updated_state.relation_filter_state == %{}
    end
  end
end

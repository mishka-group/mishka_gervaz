defmodule MishkaGervaz.Table.Types.Action.ActionMarkupTest do
  @moduledoc """
  What a row action actually puts in the DOM.

  Every other test in this directory asserts that `render/5` returns a `Phoenix.LiveView.Rendered`
  struct, which is true of a button that renders the wrong thing just as much as of one that renders
  the right thing. So the leak below lived in every table in the admin without a single failure:
  each type built its assigns map and then splatted the WHOLE map at the UI adapter, whose `button/1`
  declares `attr :rest, :global` and dutifully emitted every key it did not recognise —

      confirm="Delete the draft “…”? This cannot be undone."
      target="1"
      record_id="5d8431b3-…"

  — beside the `phx-click`, `phx-value-id`, `phx-target` and `data-confirm` that are the real
  bindings. Invalid markup on every row of every table, and `record_id` publishing a UUID into an
  attribute nothing reads.

  These tests are written as a WHITELIST rather than as a list of the three names that were wrong,
  because the failure is "a key nobody meant to render reached the DOM" — a fourth one added later
  is the same bug, and a test that names only today's three would pass on it.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Types.Action.Accordion
  alias MishkaGervaz.Table.Types.Action.Destroy
  alias MishkaGervaz.Table.Types.Action.Edit
  alias MishkaGervaz.Table.Types.Action.Event
  alias MishkaGervaz.Table.Types.Action.Link
  alias MishkaGervaz.Table.Types.Action.PermanentDestroy
  alias MishkaGervaz.Table.Types.Action.Unarchive
  alias MishkaGervaz.Table.Types.Action.Update

  @ui MishkaGervaz.UIAdapters.Tailwind
  @target %Phoenix.LiveComponent.CID{cid: 1}
  @record %{id: "5d8431b3-1a65-482e-8bdb-962f6e35841b", label: "Draft · 22 Aug"}

  # Everything `button/1` and `nav_link/1` are entitled to write. `title` is the adapter's rendering
  # of `label`; the rest are the bindings the table drives rows with.
  @button_attrs ~w(type class title phx-click phx-target phx-value-id phx-value-event
                   phx-value-values data-confirm disabled)
  @link_attrs ~w(href class title data-phx-link data-phx-link-state)

  # Rendered without LiveViewTest: a `Rendered` struct is `Phoenix.HTML.Safe`, so this is the same
  # iodata the socket would send and needs nothing beyond phoenix_html.
  defp html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  # The attribute NAMES on the first tag. Deliberately not a regex over the whole document: the
  # question is which keys reached the element, and an attribute value can contain anything.
  defp attr_names(html) do
    [opening] = Regex.run(~r/<[a-zA-Z][^>]*>/, html, capture: :first)

    ~r/(?<=\s)([a-zA-Z_][-a-zA-Z0-9_:]*)=/
    |> Regex.scan(opening, capture: :all_but_first)
    |> List.flatten()
  end

  defp assert_only(rendered, allowed) do
    names = rendered |> html() |> attr_names()
    stray = names -- allowed

    assert stray == [],
           "these reached the DOM and nothing reads them: #{Enum.join(stray, ", ")}"

    names
  end

  describe "a button action writes its bindings and nothing else" do
    test "destroy" do
      action = %{ui: %{label: "Delete", icon: "hero-trash"}, confirm: "Sure?", name: :delete}

      names =
        Destroy.render(%{}, action, @record, @ui, @target)
        |> assert_only(@button_attrs)

      assert "phx-click" in names
      assert "phx-value-id" in names
      assert "phx-target" in names
      assert "data-confirm" in names
    end

    test "permanent_destroy" do
      action = %{ui: %{label: "Delete for good"}, confirm: "Sure?", name: :permanent_destroy}

      names =
        PermanentDestroy.render(%{}, action, @record, @ui, @target)
        |> assert_only(@button_attrs)

      assert "phx-value-event" in names
    end

    test "unarchive" do
      action = %{ui: %{label: "Restore"}, confirm: "Restore?", name: :unarchive}

      Unarchive.render(%{}, action, @record, @ui, @target) |> assert_only(@button_attrs)
    end

    test "update" do
      action = %{ui: %{label: "Approve"}, confirm: nil, name: :approve, event: "approve"}

      names = Update.render(%{}, action, @record, @ui, @target) |> assert_only(@button_attrs)

      refute "data-confirm" in names, "an action with no confirm must not render an empty one"
    end

    test "event" do
      action = %{ui: %{label: "Ping"}, confirm: nil, name: :ping, event: "ping", payload: nil}

      names = Event.render(%{}, action, @record, @ui, @target) |> assert_only(@button_attrs)

      assert "phx-value-values" in names
    end

    test "edit" do
      action = %{ui: %{label: "Edit"}, confirm: nil, name: :edit, js: nil}

      names = Edit.render(%{}, action, @record, @ui, @target) |> assert_only(@button_attrs)

      assert "phx-click" in names, "the JS command is the click, and it has to survive"
    end

    test "accordion" do
      assigns = %{static: %{features: [:expand]}, state: %{expanded_id: nil}, __changed__: %{}}
      action = %{ui: %{label: "Expand"}, name: :expand}

      Accordion.render(assigns, action, @record, @ui, @target) |> assert_only(@button_attrs)
    end
  end

  describe "a link action" do
    test "writes an anchor and nothing else" do
      action = %{ui: %{label: "Open"}, name: :show_link, path: fn record -> "/x/#{record.id}" end}

      names = Link.render(%{}, action, @record, @ui, nil) |> assert_only(@link_attrs)

      assert "href" in names
    end
  end

  # THE POINT, stated once over the whole set rather than only where it was noticed.
  describe "no action type publishes its own working state" do
    test "no rendered row action carries a record id in an attribute of its own" do
      for {mod, action, assigns} <- [
            {Destroy, %{ui: %{}, confirm: "Sure?", name: :delete}, %{}},
            {PermanentDestroy, %{ui: %{}, confirm: "Sure?", name: :permanent_destroy}, %{}},
            {Unarchive, %{ui: %{}, confirm: "Sure?", name: :unarchive}, %{}},
            {Update, %{ui: %{}, confirm: nil, name: :approve, event: "approve"}, %{}},
            {Event, %{ui: %{}, confirm: nil, name: :ping, event: "ping", payload: nil}, %{}},
            {Edit, %{ui: %{}, confirm: nil, name: :edit, js: nil}, %{}},
            {Accordion, %{ui: %{}, name: :expand},
             %{static: %{features: [:expand]}, state: %{expanded_id: nil}, __changed__: %{}}}
          ] do
        names = mod |> apply(:render, [assigns, action, @record, @ui, @target]) |> attr_names_of()

        refute "record_id" in names, "#{inspect(mod)} leaked record_id"
        refute "target" in names, "#{inspect(mod)} leaked target"
        refute "confirm" in names, "#{inspect(mod)} leaked confirm"
      end
    end
  end

  defp attr_names_of(rendered), do: rendered |> html() |> attr_names()

  # THE DOCUMENTED PATTERN IS HELD TO THE SAME RULE AS THE BUILT-INS.
  #
  # `MishkaGervaz.Table.Behaviours.ActionType`'s moduledoc carries the example a developer copies
  # when they write their own type, and an example is only a contract if something runs it. This
  # module is that example, transcribed: it reads the incoming assigns for state, builds a fresh map,
  # and names its bindings `phx_*` / `data_*`. If the doc drifts back to splatting the incoming
  # assigns — or to `:record_id` and friends — this fails the way a built-in would.
  defmodule DocumentedExample do
    @behaviour MishkaGervaz.Table.Behaviours.ActionType

    use Phoenix.Component

    import MishkaGervaz.Helpers, only: [dynamic_component: 1, humanize: 1]

    @impl true
    def render(assigns, action, record, ui, target) do
      master? = assigns[:state] && assigns[:state].master_user?

      assigns =
        %{__changed__: %{}}
        |> assign(:module, ui)
        |> assign(:function, :button)
        |> assign(:label, action[:ui][:label] || humanize(action[:name]))
        |> assign(:icon, action[:ui][:icon])
        |> assign(:class, action[:ui][:class] || "text-orange-600 hover:text-orange-800")
        |> assign(:phx_click, action[:event] || "confirm")
        |> assign(:phx_value_id, record.id)
        |> assign(:phx_target, target)
        |> assign(:data_confirm, (master? && action[:confirm]) || "Are you sure?")

      ~H"""
      <.dynamic_component {assigns} />
      """
    end
  end

  describe "the example in the behaviour's moduledoc" do
    test "writes its bindings and nothing else" do
      action = %{ui: %{label: "Archive"}, confirm: "Archive this record?", name: :archive}
      state = %{master_user?: true}

      names =
        DocumentedExample.render(
          %{state: state, __changed__: %{}},
          action,
          @record,
          @ui,
          @target
        )
        |> assert_only(@button_attrs)

      assert "phx-click" in names
      assert "phx-value-id" in names
      assert "phx-target" in names
      assert "data-confirm" in names
    end

    # Reading the incoming assigns is the half the example exists to show — a type that needs the
    # table's state must be able to have it without the state reaching the markup.
    test "reads the table state without rendering it" do
      action = %{ui: %{}, confirm: "Master only", name: :archive}

      html =
        DocumentedExample.render(
          %{state: %{master_user?: false}, __changed__: %{}},
          action,
          @record,
          @ui,
          @target
        )
        |> html()

      assert html =~ "Are you sure?"
      refute html =~ "Master only"
      refute html =~ "master_user"
    end
  end
end

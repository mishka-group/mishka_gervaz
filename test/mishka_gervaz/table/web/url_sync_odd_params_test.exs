defmodule MishkaGervaz.Table.Web.UrlSyncOddParamsTest do
  @moduledoc """
  An address whose parameters hold what they may not: a map or a list where a text belongs, a null
  byte, bytes that are no UTF-8, 100 KB of text. The table takes what each parameter may be and opens
  as if the rest were not there, on the first HTTP render, on the live one and on a patch.
  """
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias MishkaGervaz.Table.Web.UrlSync
  alias MishkaGervaz.Test.Web.{FeedItem, GatedItem, KeptItem, MixedItem}

  @endpoint MishkaGervaz.Test.Web.Endpoint
  @await 5_000
  @long String.duplicate("a", 100_000)
  @id "0f0e8f5e-0d0b-4f0a-8a51-5a3f6a1f7c11"

  @names ~w(sort page page_size search template filter_search filter_note filter_status
            filter_pinned filter_size filter_day filter_period filter_owner filter_owners)

  defp decode(params), do: UrlSync.decode(params, "/mixed", MixedItem)

  defp bare(url_state),
    do: Map.take(url_state, [:filters, :sort, :page, :page_size, :search, :template])

  describe "decode" do
    test "leaves out a map, and a list where the parameter takes none" do
      none = bare(decode(%{}))

      for name <- @names,
          value <- [%{"a" => "b"}, %{"a" => %{"b" => "c"}}, [%{"a" => "b"}], [["x"]], [], %{}] do
        assert {name, value, bare(decode(%{"mixed_#{name}" => value}))} == {name, value, none}
      end

      for name <- @names -- ["filter_owners"] do
        assert {name, bare(decode(%{"mixed_#{name}" => ["draft", "x"]}))} == {name, none}
      end
    end

    test "leaves out a text too long" do
      none = bare(decode(%{}))

      for name <- @names do
        assert {name, bare(decode(%{"mixed_#{name}" => @long}))} == {name, none}
      end

      assert decode(%{"mixed_page" => String.duplicate("9", 100_000)}).page == 1
      assert decode(%{"mixed_filter_owners" => List.duplicate(@id, 100)}).filters == %{}
      assert decode(%{"keep" => [@long]}).preserved_params == %{}
    end

    test "cuts null bytes and bytes that are no UTF-8" do
      for {odd, read} <- [{"a\0b", "ab"}, {<<"a", 0xFF, "b">>, "ab"}, {<<0xC3>>, ""}, {"\0", ""}] do
        assert decode(%{"mixed_search" => odd}).search == read
        assert decode(%{"mixed_filter_note" => odd}).filters == %{note: read}
        assert decode(%{"mixed_filter_owners" => [odd, "c"]}).filters == %{owners: [read, "c"]}
        assert decode(%{"keep" => odd}).preserved_params == %{"keep" => read}
      end

      assert decode(%{"mixed_sort" => "title\0:desc"}).sort == [title: :desc]
      assert decode(%{"mixed_template" => "ta\0ble"}).template == :table
    end

    test "reads a filter's text as its type takes it" do
      read = fn name, text -> decode(%{"mixed_filter_#{name}" => text}).filters end

      assert read.("note", "Bolts, nuts ~ screws") == %{note: "Bolts, nuts ~ screws"}
      assert read.("status", "draft,published") == %{status: "draft,published"}
      assert read.("owner", "a,b") == %{owner: "a,b"}
      assert read.("owners", "a,b") == %{owners: ["a", "b"]}
      assert read.("owners", "a") == %{owners: "a"}
      assert read.("owners", ["a", "b"]) == %{owners: ["a", "b"]}

      assert read.("period", "2026-01-01~2026-02-01") ==
               %{period: %{from: "2026-01-01", to: "2026-02-01"}}

      assert read.("period", "2026-01-01~") == %{period: %{from: "2026-01-01"}}
      assert read.("period", "~2026-02-01") == %{period: %{to: "2026-02-01"}}
      assert read.("period", "2026-01-01") == %{}
      assert read.("period", "~") == %{}
    end

    test "hands a filter type of one's own a text, a list or a map, of texts" do
      read = fn value -> decode(%{"mixed_filter_shape" => value}).filters end

      assert read.("a") == %{shape: "a"}
      assert read.("a,b") == %{shape: ["a", "b"]}
      assert read.("a~b") == %{shape: %{from: "a", to: "b"}}
      assert read.(["a", "b\0"]) == %{shape: ["a", "b"]}
      assert read.(%{"from" => "a", "to" => "b\0"}) == %{shape: %{"from" => "a", "to" => "b"}}
      assert read.([%{"a" => "b"}]) == %{}
      assert read.(%{"a" => %{"b" => "c"}}) == %{}
      assert read.(%{"a" => @long}) == %{}
    end

    test "sorts only by a field of the resource or a column of its table" do
      assert decode(%{"mixed_sort" => "title:desc,nope:asc,status:sideways,size"}).sort ==
               [title: :desc, size: :asc]

      assert decode(%{"mixed_sort" => "kernel:asc,ok,"}).sort == []
    end

    test "without a resource leaves out the same" do
      opts = [allowed_params: [:filters, :sort, :page, :page_size, :search, :template]]
      none = bare(UrlSync.decode(%{}, "t", opts))

      for name <- ~w(sort page page_size search template),
          value <- [%{"a" => "b"}, ["x"], @long, [%{"a" => "b"}]] do
        assert {name, bare(UrlSync.decode(%{"t_#{name}" => value}, "t", opts))} == {name, none}
      end

      for value <- [%{"a" => %{"b" => "c"}}, [%{"a" => "b"}], @long] do
        assert UrlSync.decode(%{"t_filter_status" => value}, "t", opts).filters == %{}
        assert UrlSync.decode(%{"t_filter_#{@long}" => "x"}, "t", opts).filters == %{}
      end
    end
  end

  describe "the URL written back" do
    test "keeps a list of the page's own as it came, and leaves out what it cannot write" do
      url = "/mixed?tags[]=a&tags[]=b&deep[x]=1&mixed_filter_shape[from]=1"
      params = Plug.Conn.Query.decode(URI.parse(url).query)
      url_state = UrlSync.decode(params, url, MixedItem)

      state = %{
        filter_values: url_state.filters,
        sort_fields: [],
        page: 1,
        preserved_params: url_state.preserved_params
      }

      path = UrlSync.build_path("/mixed", state, %{params: [:filters], prefix: "mixed"})
      assert Plug.Conn.Query.decode(URI.parse(path).query) == %{"tags" => ["a", "b"]}
    end
  end

  describe "a page opened at an odd address" do
    setup do
      items =
        for resource <- [MixedItem, GatedItem, KeptItem, FeedItem],
            do: Ash.create!(resource, %{title: "Only one"})

      on_exit(fn -> Enum.each(items, &Ash.destroy!/1) end)
    end

    defp open(path) do
      {:ok, view, html} = live(build_conn(), path)
      render_async(view, @await)
      {view, html}
    end

    for {page, prefix} <- [
          {"/mixed", "mixed_"},
          {"/items", ""},
          {"/items/fixed", ""},
          {"/kept", ""},
          {"/feed", ""}
        ] do
      test "#{page} shows its rows" do
        for name <- @names, odd <- ["[a]=b", "[a][b]=c", "[][a]=b", "=%00", "[a]=%00"] do
          path = "#{unquote(page)}?#{unquote(prefix)}#{name}#{odd}"
          {view, _html} = open(path)

          assert {path, render(view) =~ "Only one"} == {path, true}
        end
      end
    end

    test "a patch to it is followed as well" do
      {view, _html} = open("/mixed")

      for query <- [
            "mixed_sort[a]=b",
            "mixed_search[a]=b",
            "mixed_filter_note[a]=b&mixed_filter_period[a]=b",
            "mixed_filter_note=a~b&mixed_filter_note=",
            "tags[]=a&tags[b]=c",
            "mixed_search=%00"
          ] do
        render_patch(view, "/mixed?" <> query)
        render_async(view, @await)
        assert {query, render(view) =~ "Only one"} == {query, true}
      end
    end

    test "a text with a comma or a ~ in a text filter is searched for as it is" do
      {view, _html} = open("/mixed?mixed_filter_note=Only,~one")

      refute render(view) =~ "Only one"
      assert has_element?(view, "input[name=note][value='Only,~one']")
    end
  end
end

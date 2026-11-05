defmodule MishkaGervaz.Table.Web.DataLoader.PaginationHandlerTest do
  @moduledoc """
  Direct unit tests for `MishkaGervaz.Table.Web.DataLoader.PaginationHandler`.

  `reset_stream?/2` decides whether a loaded page replaces what is on screen or adds to it, and
  `load_page/5` is the only thing that answers it — `load_async/3`'s own `reset:` option never reaches
  the async result. Get it wrong and the bug is invisible to a unit test of anything else: the server
  state is right (page 2 of 2), the counts are right, and the browser simply keeps page 1's rows on
  screen underneath page 2's.
  """
  use ExUnit.Case, async: true

  alias MishkaGervaz.Table.Web.DataLoader.PaginationHandler.Default, as: Handler

  describe "reset_stream?/2 for numbered pagination" do
    test "every page replaces the one before it, not just the first" do
      for page <- 1..5 do
        assert Handler.reset_stream?(:numbered, page),
               "page #{page} of a numbered table must clear the stream — asking for page #{page} " <>
                 "means the earlier pages have to go"
      end
    end
  end

  describe "reset_stream?/2 for the build-as-you-go types" do
    test "the first page clears the stream" do
      assert Handler.reset_stream?(:load_more, 1)
      assert Handler.reset_stream?(:infinite, 1)
    end

    test "later pages add to it rather than replacing it" do
      for page <- 2..5 do
        refute Handler.reset_stream?(:load_more, page)
        refute Handler.reset_stream?(:infinite, page)
      end
    end

    test "an unknown type is treated as append-style, the safer of the two" do
      assert Handler.reset_stream?(:something_new, 1)
      refute Handler.reset_stream?(:something_new, 2)
    end
  end

  describe "build_page_opts/5" do
    test "page N is the Nth slice" do
      assert Handler.build_page_opts(1, 30, :load_more, false) == [offset: 0, limit: 30]
      assert Handler.build_page_opts(3, 30, :load_more, false) == [offset: 60, limit: 30]
    end

    test "read from the start, page N is the FIRST N slices" do
      # A table that keeps its loaded records asks for this when it starts its list afresh at page
      # N — reading only the newest slice would shrink a 90-row list back to 30.
      assert Handler.build_page_opts(1, 30, :load_more, false, true) == [offset: 0, limit: 30]
      assert Handler.build_page_opts(3, 30, :load_more, false, true) == [offset: 0, limit: 90]
    end

    test "a count is still requested when the table asked for one" do
      assert Handler.build_page_opts(2, 30, :numbered, true) == [
               count: true,
               offset: 30,
               limit: 30
             ]

      assert Handler.build_page_opts(2, 30, :load_more, true, true) == [
               count: true,
               offset: 0,
               limit: 60
             ]
    end
  end
end

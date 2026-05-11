defmodule MishkaGervaz.Table.Verifiers.ValidatePaginationTest do
  @moduledoc """
  Tests for `MishkaGervaz.Table.Verifiers.ValidatePagination` — the
  resource-level pagination verifier.

  Covers:
  - invalid `page_size` (non-positive integer)
  - invalid `page_size_options` (non-positive members, empty list)
  - invalid `type` (not `:numbered` / `:infinite` / `:load_more`)
  - `page_size` not in `page_size_options`
  - `max_page_size` smaller than the largest `page_size_options` value
  """
  use ExUnit.Case, async: true

  defp resource_code(body) do
    unique_id = System.unique_integer([:positive])
    module = "MishkaGervaz.Test.PaginationVerifier#{unique_id}"

    """
    defmodule #{module} do
      use Ash.Resource,
        domain: MishkaGervaz.Test.Domain,
        extensions: [MishkaGervaz.Resource],
        data_layer: Ash.DataLayer.Ets

      mishka_gervaz do
        table do
          identity do
            name :pag_v#{unique_id}
            route "/admin/pv"
          end

          columns do
            column :name
          end

          #{body}
        end
      end

      actions do
        defaults [:read, :destroy, create: :*, update: :*]
      end

      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          public? true
        end
      end
    end
    """
  end

  defp compile_capture(body) do
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Code.compile_string(resource_code(body))
    end)
  end

  describe "negative cases — invalid page_size" do
    test "negative page_size is rejected" do
      body = """
      pagination do
        page_size -5
      end
      """

      try do
        output = compile_capture(body)
        assert output =~ "page_size"
      rescue
        e in Spark.Error.DslError ->
          assert Exception.message(e) =~ "page_size"
      end
    end

    test "zero page_size is rejected" do
      body = """
      pagination do
        page_size 0
      end
      """

      try do
        output = compile_capture(body)
        assert output =~ "page_size"
      rescue
        e in Spark.Error.DslError ->
          assert Exception.message(e) =~ "page_size"
      end
    end
  end

  describe "negative cases — invalid type" do
    test "unknown type is rejected" do
      body = """
      pagination do
        type :weird_thing
      end
      """

      try do
        output = compile_capture(body)
        assert output =~ "pagination type must be" or output =~ ":weird_thing"
      rescue
        e in Spark.Error.DslError ->
          assert Exception.message(e) =~ ":weird_thing"
      end
    end
  end

  describe "negative cases — page_size_options" do
    test "empty page_size_options is rejected" do
      body = """
      pagination do
        page_size_options []
      end
      """

      # Spark's schema validation raises directly for empty lists;
      # our verifier catches the case when the value reaches it.
      try do
        output = compile_capture(body)
        assert output =~ "page_size_options"
      rescue
        e in Spark.Error.DslError ->
          assert Exception.message(e) =~ "page_size_options"
      end
    end

    test "page_size_options with negative member is rejected" do
      body = """
      pagination do
        page_size_options [-1, 20]
      end
      """

      try do
        output = compile_capture(body)
        assert output =~ "page_size_options"
      rescue
        e in Spark.Error.DslError ->
          assert Exception.message(e) =~ "page_size_options"
      end
    end
  end

  describe "negative cases — page_size_in_options mismatch" do
    test "page_size not in page_size_options is rejected" do
      body = """
      pagination do
        page_size 7
        page_size_options [20, 50, 100]
      end
      """

      output = compile_capture(body)
      assert output =~ "is not included in page_size_options"
    end
  end

  describe "negative cases — max_page_size mismatch" do
    test "max_page_size less than largest page_size_options is rejected" do
      body = """
      pagination do
        page_size 20
        page_size_options [20, 50, 100]
        max_page_size 30
      end
      """

      output = compile_capture(body)
      assert output =~ "max_page_size" and output =~ "less than"
    end
  end

  describe "positive cases" do
    # Positive cases check that compilation succeeds without raising.
    # We can't assert against stderr because async tests share stderr
    # and Spark DslErrors from concurrent test runs leak into the buffer.

    test "valid pagination block compiles" do
      body = """
      pagination do
        type :numbered
        page_size 20
        page_size_options [20, 50, 100]
        max_page_size 100
      end
      """

      # Compiles without raising = positive.
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(resource_code(body))
      end)
    end

    test "no pagination block compiles (no requirement to declare)" do
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(resource_code(""))
      end)
    end
  end
end

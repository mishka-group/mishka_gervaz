defmodule MishkaGervaz.Table.Verifiers.ValidateLayoutTest do
  @moduledoc """
  Tests for the table chrome verifier — duplicate notices, invalid positions,
  unknown column references.
  """
  use ExUnit.Case, async: true

  defp resource_code(body) do
    unique_id = System.unique_integer([:positive])
    module = "MishkaGervaz.Test.TableLayoutVerifier#{unique_id}"

    """
    defmodule #{module} do
      use Ash.Resource,
        domain: MishkaGervaz.Test.Domain,
        extensions: [MishkaGervaz.Resource],
        data_layer: Ash.DataLayer.Ets

      mishka_gervaz do
        table do
          identity do
            name :verifier_t#{unique_id}
            route "/admin/tv"
          end

          columns do
            column :name
            column :status
          end

          #{body}
        end
      end

      actions do
        defaults [:read, :destroy, create: :*, update: :*]

        read :master_read
        read :tenant_read
      end

      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          public? true
        end

        attribute :status, :string do
          public? true
        end

        create_timestamp :inserted_at
        update_timestamp :updated_at
      end
    end
    """
  end

  defp compile_capture(body) do
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Code.compile_string(resource_code(body))
    end)
  end

  test "duplicate notice names is rejected" do
    body = """
    layout do
      notice :dup do
        position :table_top
        type :info
      end

      notice :dup do
        position :before_table
        type :error
      end
    end
    """

    output = compile_capture(body)
    assert output =~ "Duplicate notice names" or output =~ "must be unique"
    assert output =~ "Spark.Error.DslError"
  end

  test "invalid notice position atom is rejected" do
    body = """
    layout do
      notice :bad_pos do
        position :somewhere_invalid
        type :info
      end
    end
    """

    output = compile_capture(body)
    assert output =~ "invalid notice position"
    assert output =~ "Spark.Error.DslError"
  end

  test "{:after_column, :unknown} is rejected" do
    body = """
    layout do
      notice :wrong_column do
        position {:after_column, :nonexistent}
        type :info
      end
    end
    """

    output = compile_capture(body)
    assert output =~ "unknown column"
    assert output =~ "Spark.Error.DslError"
  end

  test "valid chrome compiles into a working module" do
    body = """
    layout do
      header do
        title "OK"
      end

      notice :good do
        position :table_top
        type :info
      end

      notice :col_scoped do
        position {:before_column, :status}
        type :warning
      end
    end
    """

    code = resource_code(body)

    modules =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        send(self(), {:result, Code.compile_string(code)})
      end)
      |> then(fn _ ->
        assert_received {:result, mods}
        mods
      end)

    {module, _bin} =
      Enum.find(modules, fn {m, _} ->
        s = Atom.to_string(m)

        String.contains?(s, "TableLayoutVerifier") and
          not String.starts_with?(s, "Elixir.Inspect.")
      end)

    notices = MishkaGervaz.Resource.Info.Table.notices(module)
    assert Enum.map(notices, & &1.name) == [:good, :col_scoped]
  end
end

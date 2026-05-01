defmodule MishkaGervaz.Form.Verifiers.ValidateChromeTest do
  @moduledoc """
  Tests for the chrome verifier — duplicate notices, invalid positions,
  unknown group references, and unknown only_steps.
  """
  use ExUnit.Case, async: true

  defp resource_code(body) do
    unique_id = System.unique_integer([:positive])
    module = "MishkaGervaz.Test.ChromeVerifier#{unique_id}"

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
            route "/admin/v"
          end

          columns do
            column :name
          end
        end

        form do
          identity do
            name :verifier_form#{unique_id}
            route "/admin/v"
          end

          source do
            master_check fn user -> user && user.role == :admin end

            actions do
              create {:master_create, :create}
              update {:master_update, :update}
              read {:master_get, :read}
            end
          end

          fields do
            field :name, :text do
              required true
            end
          end

          groups do
            group :basic do
              fields [:name]
            end
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
        position :form_top
        type :info
      end

      notice :dup do
        position :form_bottom
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

  test "{:after_group, :unknown} is rejected" do
    body = """
    layout do
      notice :wrong_group do
        position {:after_group, :nonexistent}
        type :info
      end
    end
    """

    output = compile_capture(body)
    assert output =~ "unknown group"
    assert output =~ "Spark.Error.DslError"
  end

  test "only_steps referencing unknown step is rejected" do
    body = """
    layout do
      notice :scoped do
        position :form_top
        type :info
        only_steps [:nonexistent_step]
      end
    end
    """

    output = compile_capture(body)
    assert output =~ "unknown steps"
    assert output =~ "Spark.Error.DslError"
  end

  test "valid chrome compiles into a working module" do
    body = """
    layout do
      header do
        title "OK"
      end

      notice :good do
        position :form_top
        type :info
      end

      notice :group_scoped do
        position {:after_group, :basic}
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
        String.contains?(s, "ChromeVerifier") and not String.starts_with?(s, "Elixir.Inspect.")
      end)

    notices = MishkaGervaz.Resource.Info.Form.notices(module)
    assert Enum.map(notices, & &1.name) == [:good, :group_scoped]
  end
end

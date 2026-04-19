defmodule MishkaGervaz.Form.Verifiers.ValidatePreloadsTest do
  @moduledoc """
  Tests for the ValidatePreloads verifier.
  """
  use ExUnit.Case, async: true

  describe "negative: preload with required pagination" do
    test "emits DslError when preload relationship has required pagination" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.PaginatedTarget#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          read :paginated_read do
            pagination offset?: true, default_limit: 20, countable: true
          end
        end
      end

      defmodule MishkaGervaz.Test.PreloadBadPagination#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        relationships do
          has_many :items, MishkaGervaz.Test.PaginatedTarget#{unique_id} do
            read_action :paginated_read
          end
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :preload_bad_#{unique_id}
              route "/admin/preload-bad-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            source do
              preload do
                always [:items]
              end
            end

            fields do
              field :title, :text
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      assert output =~ "pagination required?: true"
      assert output =~ "required?: false"
    end
  end

  describe "positive: preload with optional pagination" do
    test "compiles without error when preload relationship has required?: false" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.OptionalPagTarget#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          read :optional_pag_read do
            pagination offset?: true, default_limit: 20, required?: false
          end
        end
      end

      defmodule MishkaGervaz.Test.PreloadGoodPagination#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        relationships do
          has_many :items, MishkaGervaz.Test.OptionalPagTarget#{unique_id} do
            read_action :optional_pag_read
          end
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :preload_good_#{unique_id}
              route "/admin/preload-good-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            source do
              preload do
                always [:items]
              end
            end

            fields do
              field :title, :text
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      refute output =~ "pagination required?"
    end

    test "compiles without error when preload relationship has no pagination" do
      unique_id = System.unique_integer([:positive])

      code = """
      defmodule MishkaGervaz.Test.NoPagTarget#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end
      end

      defmodule MishkaGervaz.Test.PreloadNoPag#{unique_id} do
        use Ash.Resource,
          domain: MishkaGervaz.Test.Domain,
          extensions: [MishkaGervaz.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
        end

        relationships do
          has_many :items, MishkaGervaz.Test.NoPagTarget#{unique_id}
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end

        mishka_gervaz do
          table do
            identity do
              name :preload_nopag_#{unique_id}
              route "/admin/preload-nopag-#{unique_id}"
            end

            columns do
              column :title
            end
          end

          form do
            source do
              preload do
                always [:items]
              end
            end

            fields do
              field :title, :text
            end
          end
        end
      end
      """

      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(code)
        end)

      refute output =~ "pagination required?"
    end
  end
end

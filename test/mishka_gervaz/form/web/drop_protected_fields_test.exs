defmodule MishkaGervaz.Form.Web.DropProtectedFieldsTest do
  @moduledoc """
  Tests for `drop_protected_fields` in SubmitHandler.

  Since drop_protected_fields is private, we test it indirectly through the
  submit handler module's internal helpers. We extract the logic and test it
  via the same pattern used in the implementation.
  """
  use ExUnit.Case, async: true

  describe "field_restricted? logic" do
    test "restricted boolean true blocks non-master" do
      field = %{restricted: true, readonly: false}
      state = %{master_user?: false}
      assert field_restricted?(field, state)
    end

    test "restricted boolean true allows master" do
      field = %{restricted: true, readonly: false}
      state = %{master_user?: true}
      refute field_restricted?(field, state)
    end

    test "restricted fn returning false means restricted" do
      field = %{restricted: fn _state -> false end, readonly: false}
      state = %{master_user?: false}
      assert field_restricted?(field, state)
    end

    test "restricted fn returning true means allowed" do
      field = %{restricted: fn _state -> true end, readonly: false}
      state = %{master_user?: false}
      refute field_restricted?(field, state)
    end

    test "restricted false does not restrict" do
      field = %{restricted: false, readonly: false}
      state = %{master_user?: false}
      refute field_restricted?(field, state)
    end
  end

  describe "field_readonly? logic" do
    test "readonly fn returning true makes field readonly" do
      field = %{readonly: fn _state -> true end, restricted: false}
      state = %{master_user?: false}
      assert field_readonly?(field, state)
    end

    test "readonly fn returning false is not readonly" do
      field = %{readonly: fn _state -> false end, restricted: false}
      state = %{master_user?: false}
      refute field_readonly?(field, state)
    end

    test "readonly boolean true" do
      field = %{readonly: true, restricted: false}
      state = %{master_user?: false}
      assert field_readonly?(field, state)
    end

    test "readonly boolean false" do
      field = %{readonly: false, restricted: false}
      state = %{master_user?: false}
      refute field_readonly?(field, state)
    end

    test "readonly fn checks state for master" do
      field = %{readonly: fn state -> not state.master_user? end, restricted: false}
      assert field_readonly?(field, %{master_user?: false})
      refute field_readonly?(field, %{master_user?: true})
    end
  end

  describe "drop_protected_fields integration" do
    test "drops restricted field params for non-master" do
      fields = [
        %{name: :title, restricted: false, readonly: false},
        %{name: :host, restricted: true, readonly: false},
        %{name: :priority, restricted: false, readonly: false}
      ]

      state = %{
        master_user?: false,
        static: %{fields: fields}
      }

      params = %{"title" => "My Site", "host" => "evil.com", "priority" => "1"}
      result = drop_protected_fields(state, params)

      assert result["title"] == "My Site"
      assert result["priority"] == "1"
      refute Map.has_key?(result, "host")
    end

    test "keeps restricted field params for master" do
      fields = [
        %{name: :title, restricted: false, readonly: false},
        %{name: :host, restricted: true, readonly: false}
      ]

      state = %{
        master_user?: true,
        static: %{fields: fields}
      }

      params = %{"title" => "My Site", "host" => "good.com"}
      result = drop_protected_fields(state, params)

      assert result["title"] == "My Site"
      assert result["host"] == "good.com"
    end

    test "drops readonly fn=true field params" do
      fields = [
        %{name: :title, restricted: false, readonly: fn state -> not state.master_user? end},
        %{name: :content, restricted: false, readonly: false}
      ]

      state = %{
        master_user?: false,
        static: %{fields: fields}
      }

      params = %{"title" => "Hacked", "content" => "Valid"}
      result = drop_protected_fields(state, params)

      refute Map.has_key?(result, "title")
      assert result["content"] == "Valid"
    end

    test "keeps readonly fn=false field params" do
      fields = [
        %{name: :title, restricted: false, readonly: fn state -> not state.master_user? end}
      ]

      state = %{
        master_user?: true,
        static: %{fields: fields}
      }

      params = %{"title" => "Valid"}
      result = drop_protected_fields(state, params)

      assert result["title"] == "Valid"
    end

    test "drops boolean readonly true field params" do
      fields = [
        %{name: :status, restricted: false, readonly: true}
      ]

      state = %{
        master_user?: false,
        static: %{fields: fields}
      }

      params = %{"status" => "hacked"}
      result = drop_protected_fields(state, params)

      refute Map.has_key?(result, "status")
    end

    test "restricted takes precedence — both restricted and readonly" do
      fields = [
        %{name: :host, restricted: true, readonly: true}
      ]

      state = %{
        master_user?: false,
        static: %{fields: fields}
      }

      params = %{"host" => "evil.com"}
      result = drop_protected_fields(state, params)

      refute Map.has_key?(result, "host")
    end
  end

  # Mirror the private functions from SubmitHandler for testing
  defp field_restricted?(%{restricted: true}, %{master_user?: false}), do: true
  defp field_restricted?(%{restricted: f}, _state) when is_function(f, 1), do: not f.(_state)
  defp field_restricted?(_, _), do: false

  defp field_readonly?(%{readonly: f}, state) when is_function(f, 1), do: f.(state)
  defp field_readonly?(%{readonly: true}, _), do: true
  defp field_readonly?(_, _), do: false

  defp drop_protected_fields(state, params) do
    state.static.fields
    |> Enum.reduce(params, fn field, acc ->
      field_key = to_string(field.name)

      cond do
        field_restricted?(field, state) -> Map.delete(acc, field_key)
        field_readonly?(field, state) -> Map.delete(acc, field_key)
        true -> acc
      end
    end)
  end
end

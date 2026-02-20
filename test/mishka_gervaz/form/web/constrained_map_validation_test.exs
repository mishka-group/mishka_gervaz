defmodule MishkaGervaz.Form.Web.ConstrainedMapValidationTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias MishkaGervaz.Form.Templates.Standard

  describe "blank_sub_value?" do
    test "nil is blank" do
      assert Standard.blank_sub_value?(nil)
    end

    test "empty string is blank" do
      assert Standard.blank_sub_value?("")
    end

    test "whitespace-only string is blank" do
      assert Standard.blank_sub_value?("  ")
    end

    test "empty map is NOT blank (key fix)" do
      refute Standard.blank_sub_value?(%{})
    end

    test "empty list is NOT blank" do
      refute Standard.blank_sub_value?([])
    end

    test "non-empty string is NOT blank" do
      refute Standard.blank_sub_value?("hello")
    end

    test "map with data is NOT blank" do
      refute Standard.blank_sub_value?(%{"key" => "val"})
    end
  end

  describe "compute_sub_field_errors/3 with boolean (backward compat)" do
    test "true enables all errors" do
      nested_fields = [
        %{name: :name, type: :text, label: "Name", required: true, placeholder: "Name"}
      ]

      entry = %{"name" => nil}
      errors = Standard.compute_sub_field_errors(entry, nested_fields, true)

      assert "is required" in errors[:name]
    end

    test "false disables all errors" do
      nested_fields = [
        %{name: :name, type: :text, label: "Name", required: true, placeholder: "Name"}
      ]

      entry = %{"name" => nil}
      errors = Standard.compute_sub_field_errors(entry, nested_fields, false)

      assert errors == %{}
    end
  end

  describe "compute_sub_field_errors/3 with error_mode map" do
    test "required: true, type: true shows all errors" do
      nested_fields = [
        %{name: :name, type: :text, label: "Name", required: true, placeholder: "Name"},
        %{name: :opts, type: :json, label: "Options", required: false, placeholder: "{}"}
      ]

      entry = %{"name" => nil, "opts" => "bad json"}

      errors =
        Standard.compute_sub_field_errors(entry, nested_fields, %{required: true, type: true})

      assert "is required" in errors[:name]
      assert "must be valid JSON" in errors[:opts]
    end

    test "required: false, type: true shows only type errors" do
      nested_fields = [
        %{name: :name, type: :text, label: "Name", required: true, placeholder: "Name"},
        %{name: :opts, type: :json, label: "Options", required: false, placeholder: "{}"}
      ]

      entry = %{"name" => nil, "opts" => "bad json"}

      errors =
        Standard.compute_sub_field_errors(entry, nested_fields, %{required: false, type: true})

      refute Map.has_key?(errors, :name)
      assert "must be valid JSON" in errors[:opts]
    end

    test "required: true, type: false shows only required errors" do
      nested_fields = [
        %{name: :name, type: :text, label: "Name", required: true, placeholder: "Name"},
        %{name: :opts, type: :json, label: "Options", required: false, placeholder: "{}"}
      ]

      entry = %{"name" => nil, "opts" => "bad json"}

      errors =
        Standard.compute_sub_field_errors(entry, nested_fields, %{required: true, type: false})

      assert "is required" in errors[:name]
      refute Map.has_key?(errors, :opts)
    end

    test "required: false, type: false returns empty" do
      nested_fields = [
        %{name: :name, type: :text, label: "Name", required: true, placeholder: "Name"}
      ]

      entry = %{"name" => nil}

      errors =
        Standard.compute_sub_field_errors(entry, nested_fields, %{required: false, type: false})

      assert errors == %{}
    end
  end

  describe "validate_sub_field_value/4 — type module integration" do
    test "required text field with nil" do
      sf = %{name: :name, type: :text, required: true, label: "Name", placeholder: "Name"}
      errors = Standard.validate_sub_field_value(nil, sf)
      assert "is required" in errors
    end

    test "required text field with valid value" do
      sf = %{name: :name, type: :text, required: true, label: "Name", placeholder: "Name"}
      errors = Standard.validate_sub_field_value("hello", sf)
      assert errors == []
    end

    test "optional text field with nil" do
      sf = %{name: :name, type: :text, required: false, label: "Name", placeholder: "Name"}
      errors = Standard.validate_sub_field_value(nil, sf)
      assert errors == []
    end

    test "json field with invalid string — type error via module" do
      sf = %{name: :opts, type: :json, required: false, label: "Opts", placeholder: "{}"}
      errors = Standard.validate_sub_field_value("bad json", sf)
      assert "must be valid JSON" in errors
    end

    test "json field with decoded map value is valid" do
      sf = %{name: :opts, type: :json, required: false, label: "Opts", placeholder: "{}"}
      errors = Standard.validate_sub_field_value(%{"key" => "val"}, sf)
      assert errors == []
    end

    test "json field with nil is valid (not required)" do
      sf = %{name: :opts, type: :json, required: false, label: "Opts", placeholder: "{}"}
      errors = Standard.validate_sub_field_value(nil, sf)
      assert errors == []
    end

    test "required json field with nil shows required but not type error" do
      sf = %{name: :opts, type: :json, required: true, label: "Opts", placeholder: "{}"}
      errors = Standard.validate_sub_field_value(nil, sf)
      assert "is required" in errors
      refute "must be valid JSON" in errors
    end

    test "number field with non-numeric string" do
      sf = %{name: :count, type: :number, required: false, label: "Count", placeholder: "0"}
      errors = Standard.validate_sub_field_value("abc", sf)
      assert "must be a number" in errors
    end

    test "number field with numeric string" do
      sf = %{name: :count, type: :number, required: false, label: "Count", placeholder: "0"}
      errors = Standard.validate_sub_field_value("42", sf)
      assert errors == []
    end

    test "number field with float string" do
      sf = %{name: :count, type: :number, required: false, label: "Count", placeholder: "0"}
      errors = Standard.validate_sub_field_value("3.14", sf)
      assert errors == []
    end

    test "date field with invalid string" do
      sf = %{name: :date, type: :date, required: false, label: "Date", placeholder: ""}
      errors = Standard.validate_sub_field_value("not-a-date", sf)
      assert "must be a valid date" in errors
    end

    test "date field with valid ISO date" do
      sf = %{name: :date, type: :date, required: false, label: "Date", placeholder: ""}
      errors = Standard.validate_sub_field_value("2024-01-15", sf)
      assert errors == []
    end

    test "datetime field with invalid string" do
      sf = %{name: :dt, type: :datetime, required: false, label: "DateTime", placeholder: ""}
      errors = Standard.validate_sub_field_value("not-a-datetime", sf)
      assert "must be a valid date and time" in errors
    end

    test "datetime field with valid datetime-local format" do
      sf = %{name: :dt, type: :datetime, required: false, label: "DateTime", placeholder: ""}
      errors = Standard.validate_sub_field_value("2024-01-15T10:30:00", sf)
      assert errors == []
    end

    test "show_required=false skips required check" do
      sf = %{name: :name, type: :text, required: true, label: "Name", placeholder: "Name"}
      errors = Standard.validate_sub_field_value(nil, sf, false, true)
      assert errors == []
    end

    test "show_type=false skips type check" do
      sf = %{name: :opts, type: :json, required: false, label: "Opts", placeholder: "{}"}
      errors = Standard.validate_sub_field_value("bad json", sf, true, false)
      assert errors == []
    end

    test "entry with %{} opts — not an error" do
      sf = %{name: :opts, type: :json, required: false, label: "Options", placeholder: "{}"}
      errors = Standard.validate_sub_field_value(%{}, sf)
      assert errors == []
    end
  end

  describe "validate_sub_field_value/4 — ash_type-aware validation" do
    test "json field with ash_type :map rejects bare number string" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: :map
      }

      errors = Standard.validate_sub_field_value("1", sf)
      assert "must be a JSON object" in errors
    end

    test "json field with ash_type :map rejects JSON array string" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: :map
      }

      errors = Standard.validate_sub_field_value("[1,2]", sf)
      assert "must be a JSON object" in errors
    end

    test "json field with ash_type :map accepts valid object string" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: :map
      }

      errors = Standard.validate_sub_field_value("{\"key\":\"val\"}", sf)
      assert errors == []
    end

    test "json field with ash_type :map rejects decoded list" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: :map
      }

      errors = Standard.validate_sub_field_value([1, 2], sf)
      assert "must be a JSON object" in errors
    end

    test "json field with ash_type :map accepts decoded map" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: :map
      }

      errors = Standard.validate_sub_field_value(%{"key" => "val"}, sf)
      assert errors == []
    end

    test "json field with ash_type {:array, :map} rejects bare number string" do
      sf = %{
        name: :items,
        type: :json,
        required: false,
        label: "Items",
        placeholder: "[]",
        ash_type: {:array, :map}
      }

      errors = Standard.validate_sub_field_value("1", sf)
      assert "must be a JSON array" in errors
    end

    test "json field with ash_type {:array, :map} rejects object string" do
      sf = %{
        name: :items,
        type: :json,
        required: false,
        label: "Items",
        placeholder: "[]",
        ash_type: {:array, :map}
      }

      errors = Standard.validate_sub_field_value("{\"a\":1}", sf)
      assert "must be a JSON array" in errors
    end

    test "json field with ash_type {:array, :map} accepts array string" do
      sf = %{
        name: :items,
        type: :json,
        required: false,
        label: "Items",
        placeholder: "[]",
        ash_type: {:array, :map}
      }

      errors = Standard.validate_sub_field_value("[{\"a\":1}]", sf)
      assert errors == []
    end

    test "json field without ash_type accepts any valid JSON" do
      sf = %{name: :data, type: :json, required: false, label: "Data", placeholder: "{}"}
      assert Standard.validate_sub_field_value("1", sf) == []
      assert Standard.validate_sub_field_value("[1]", sf) == []
      assert Standard.validate_sub_field_value("{\"a\":1}", sf) == []
    end

    test "number field with ash_type :integer rejects float string" do
      sf = %{
        name: :count,
        type: :number,
        required: false,
        label: "Count",
        placeholder: "0",
        ash_type: :integer
      }

      errors = Standard.validate_sub_field_value("3.14", sf)
      assert "must be a whole number" in errors
    end

    test "number field with ash_type :integer accepts integer string" do
      sf = %{
        name: :count,
        type: :number,
        required: false,
        label: "Count",
        placeholder: "0",
        ash_type: :integer
      }

      errors = Standard.validate_sub_field_value("42", sf)
      assert errors == []
    end

    test "number field with ash_type :integer rejects float value" do
      sf = %{
        name: :count,
        type: :number,
        required: false,
        label: "Count",
        placeholder: "0",
        ash_type: :integer
      }

      errors = Standard.validate_sub_field_value(3.14, sf)
      assert "must be a whole number" in errors
    end

    test "number field without ash_type accepts float string" do
      sf = %{name: :count, type: :number, required: false, label: "Count", placeholder: "0"}
      errors = Standard.validate_sub_field_value("3.14", sf)
      assert errors == []
    end

    test "compute_sub_field_errors passes ash_type through" do
      nested_fields = [
        %{
          name: :opts,
          type: :json,
          label: "Options",
          required: false,
          placeholder: "{}",
          ash_type: :map
        }
      ]

      entry = %{"opts" => "1"}

      errors =
        Standard.compute_sub_field_errors(entry, nested_fields, %{required: false, type: true})

      assert "must be a JSON object" in errors[:opts]
    end

    test "json field with Ash.Type.Map rejects bare number string" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: Ash.Type.Map
      }

      errors = Standard.validate_sub_field_value("1", sf)
      assert "must be a JSON object" in errors
    end

    test "json field with Ash.Type.Map accepts valid object string" do
      sf = %{
        name: :opts,
        type: :json,
        required: false,
        label: "Options",
        placeholder: "{}",
        ash_type: Ash.Type.Map
      }

      errors = Standard.validate_sub_field_value("{\"key\":\"val\"}", sf)
      assert errors == []
    end

    test "json field with {:array, Ash.Type.Map} rejects object string" do
      sf = %{
        name: :items,
        type: :json,
        required: false,
        label: "Items",
        placeholder: "[]",
        ash_type: {:array, Ash.Type.Map}
      }

      errors = Standard.validate_sub_field_value("{\"a\":1}", sf)
      assert "must be a JSON array" in errors
    end

    test "json field with {:array, Ash.Type.Map} accepts array string" do
      sf = %{
        name: :items,
        type: :json,
        required: false,
        label: "Items",
        placeholder: "[]",
        ash_type: {:array, Ash.Type.Map}
      }

      errors = Standard.validate_sub_field_value("[{\"a\":1}]", sf)
      assert errors == []
    end

    test "number field with Ash.Type.Integer rejects float string" do
      sf = %{
        name: :count,
        type: :number,
        required: false,
        label: "Count",
        placeholder: "0",
        ash_type: Ash.Type.Integer
      }

      errors = Standard.validate_sub_field_value("3.14", sf)
      assert "must be a whole number" in errors
    end
  end
end

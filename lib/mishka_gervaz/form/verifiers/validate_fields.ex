defmodule MishkaGervaz.Form.Verifiers.ValidateFields do
  @moduledoc """
  Validates the `fields` section of MishkaGervaz form DSL.

  Four checks, in order:

    1. Each field name maps to a resource attribute, relationship,
       calculation, or aggregate — unless the field is marked `virtual`.
    2. `depends_on` references a field declared in the same form.
    3. Virtual fields of type `:relation` or `:select` declare a `resource`.
    4. `nested_field` entries appear only inside `:nested` fields.

  See `MishkaGervaz.Form.Dsl.Fields`,
  `MishkaGervaz.Form.Entities.Field`,
  `MishkaGervaz.Form.Entities.NestedField`,
  `MishkaGervaz.Form.Verifiers.Helpers`, and sibling verifiers.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Form.Entities.{Field, NestedField}

  import MishkaGervaz.Form.Verifiers.Helpers, only: [dsl_error: 3, entities_of: 3]

  @path [:mishka_gervaz, :form, :fields]

  @impl true
  @spec verify(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    fields = entities_of(dsl_state, @path, Field)
    field_names = Enum.map(fields, & &1.name)

    with :ok <- validate_field_references(fields, collect_resource_fields(module), module),
         :ok <- validate_depends_on(fields, field_names, module),
         :ok <- validate_virtual_fields(fields, module),
         :ok <- validate_nested_field_placement(fields, module),
         do: :ok
  end

  defp collect_resource_fields(module) do
    if function_exported?(module, :spark_dsl_config, 0) do
      [
        Ash.Resource.Info.attributes(module),
        Ash.Resource.Info.relationships(module),
        Ash.Resource.Info.calculations(module),
        Ash.Resource.Info.aggregates(module)
      ]
      |> List.flatten()
      |> Enum.map(& &1.name)
    else
      []
    end
  rescue
    _ -> []
  end

  defp validate_field_references(fields, resource_fields, module) do
    Enum.find_value(fields, :ok, &check_field_reference(&1, resource_fields, module))
  end

  defp check_field_reference(%{virtual: true}, _resource_fields, _module), do: nil

  defp check_field_reference(field, resource_fields, module) do
    if field.name in resource_fields do
      nil
    else
      dsl_error(module, @path ++ [field.name], not_a_resource_field_message(field))
    end
  end

  defp validate_depends_on(fields, field_names, module) do
    Enum.find_value(fields, :ok, &check_depends_on(&1, field_names, module))
  end

  defp check_depends_on(%{depends_on: nil}, _field_names, _module), do: nil

  defp check_depends_on(%{depends_on: dep} = field, field_names, module) do
    if dep in field_names do
      nil
    else
      dsl_error(
        module,
        @path ++ [field.name],
        "Field `#{field.name}` depends_on `#{dep}` which is not a defined field."
      )
    end
  end

  defp validate_virtual_fields(fields, module) do
    Enum.find_value(fields, :ok, &check_virtual_field(&1, module))
  end

  defp check_virtual_field(%{virtual: true, type: type, resource: nil} = field, module)
       when type in [:relation, :select] do
    dsl_error(module, @path ++ [field.name], virtual_needs_resource_message(field))
  end

  defp check_virtual_field(_field, _module), do: nil

  defp validate_nested_field_placement(fields, module) do
    Enum.find_value(fields, :ok, &check_nested_placement(&1, module))
  end

  defp check_nested_placement(field, module) do
    if has_nested_entries?(field) and field.type not in [:nested, nil] do
      dsl_error(module, @path ++ [field.name], nested_misplaced_message(field))
    else
      nil
    end
  end

  defp has_nested_entries?(%{nested_fields: list}) when is_list(list) do
    Enum.any?(list, &is_struct(&1, NestedField))
  end

  defp has_nested_entries?(_), do: false

  defp not_a_resource_field_message(field) do
    """
    Field `#{field.name}` is not a resource attribute.

    If this is a computed/virtual field, add `virtual: true`:

        field :#{field.name}, :text do
          virtual true
        end
    """
  end

  defp virtual_needs_resource_message(field) do
    """
    Virtual field `#{field.name}` of type `#{field.type}` requires `resource` option.

        field :#{field.name}, :#{field.type} do
          virtual true
          resource MyApp.SomeResource
        end
    """
  end

  defp nested_misplaced_message(field) do
    """
    `nested_field` is only allowed inside fields with type `:nested`.

    Field `#{field.name}` has type `#{inspect(field.type)}`.
    Either change the type to `:nested` or remove the nested_field entries.
    """
  end
end

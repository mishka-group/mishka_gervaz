defmodule MishkaGervaz.Table.Verifiers.ValidatePagination do
  @moduledoc """
  Validates pagination configuration at the resource level.

  Ensures:
  - page_size is a positive integer (when explicitly set)
  - page_size_options are all positive integers (when explicitly set)
  - page_size is included in page_size_options (when both are set)
  - pagination type is valid
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier
  alias MishkaGervaz.Table.Entities.Pagination

  @table_path [:mishka_gervaz, :table]

  @impl true
  def verify(dsl_state) do
    route = Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :identity], :route)

    if is_nil(route) do
      :ok
    else
      do_verify(dsl_state)
    end
  end

  defp do_verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    pagination =
      dsl_state
      |> Verifier.get_entities(@table_path)
      |> List.wrap()
      |> Enum.find(&match?(%Pagination{}, &1))

    validate_pagination(pagination, module)
  end

  defp validate_pagination(nil, _module), do: :ok

  defp validate_pagination(%Pagination{} = pagination, module) do
    with :ok <- validate_page_size(pagination.page_size, module),
         :ok <- validate_page_size_options(pagination.page_size_options, module),
         :ok <- validate_type(pagination.type, module),
         :ok <-
           validate_page_size_in_options(
             pagination.page_size,
             pagination.page_size_options,
             module
           ),
         :ok <-
           validate_max_page_size(pagination.max_page_size, pagination.page_size_options, module) do
      :ok
    end
  end

  defp validate_page_size(nil, _module), do: :ok
  defp validate_page_size(size, _module) when is_integer(size) and size > 0, do: :ok

  defp validate_page_size(size, module) do
    message = """
    page_size must be a positive integer, got: #{inspect(size)}

    Fix: Set a valid page_size in your resource's pagination block:

        mishka_gervaz do
          table do
            pagination do
              page_size 20
            end
          end
        end

    Or set it in the domain's mishka_gervaz config as a default for all resources.
    """

    dsl_error(module, [:mishka_gervaz, :table, :pagination, :page_size], message)
  end

  defp validate_page_size_options(nil, _module), do: :ok

  defp validate_page_size_options([], module) do
    message = """
    page_size_options cannot be an empty list.

    Fix: Provide at least one page size option:

        pagination do
          page_size_options [20, 50, 100]
        end
    """

    dsl_error(module, [:mishka_gervaz, :table, :pagination, :page_size_options], message)
  end

  defp validate_page_size_options(options, module) when is_list(options) do
    invalid = Enum.reject(options, &(is_integer(&1) and &1 > 0))

    if invalid == [] do
      :ok
    else
      message = """
      page_size_options must all be positive integers, got invalid values: #{inspect(invalid)}

      Fix: Ensure all options are positive integers:

          pagination do
            page_size_options [20, 50, 100]
          end
      """

      dsl_error(module, [:mishka_gervaz, :table, :pagination, :page_size_options], message)
    end
  end

  defp validate_page_size_options(_, _), do: :ok

  defp validate_type(nil, _module), do: :ok
  defp validate_type(t, _module) when t in [:numbered, :infinite, :load_more], do: :ok

  defp validate_type(type, module) do
    message = """
    pagination type must be one of :numbered, :infinite, or :load_more, got: #{inspect(type)}

    Fix: Set a valid pagination type:

        pagination do
          type :numbered
        end
    """

    dsl_error(module, [:mishka_gervaz, :table, :pagination, :type], message)
  end

  defp validate_page_size_in_options(nil, _options, _module), do: :ok
  defp validate_page_size_in_options(_size, nil, _module), do: :ok

  defp validate_page_size_in_options(size, options, module) when is_list(options) do
    if size in options do
      :ok
    else
      message = """
      page_size #{inspect(size)} is not included in page_size_options #{inspect(options)}.

      The default page_size should be one of the available page_size_options so users
      can select it in the page size dropdown.

      Fix: Either add #{inspect(size)} to page_size_options, or change page_size to one of #{inspect(options)}:

          pagination do
            page_size #{inspect(List.first(options))}
            page_size_options #{inspect(options)}
          end
      """

      dsl_error(module, [:mishka_gervaz, :table, :pagination], message)
    end
  end

  defp validate_page_size_in_options(_, _, _), do: :ok

  defp validate_max_page_size(nil, _options, _module), do: :ok

  defp validate_max_page_size(max, _options, _module) when not is_integer(max) or max <= 0 do
    :ok
  end

  defp validate_max_page_size(max, options, module) when is_list(options) and options != [] do
    max_option = Enum.max(options)

    if max >= max_option do
      :ok
    else
      message = """
      max_page_size #{inspect(max)} is less than the largest page_size_options value #{inspect(max_option)}.

      max_page_size must be >= the largest value in page_size_options.

      Fix: Increase max_page_size or reduce page_size_options:

          pagination do
            page_size_options #{inspect(options)}
            max_page_size #{inspect(max_option)}
          end
      """

      dsl_error(module, [:mishka_gervaz, :table, :pagination, :max_page_size], message)
    end
  end

  defp validate_max_page_size(_, _, _), do: :ok

  defp dsl_error(module, path, message) do
    {:error, Spark.Error.DslError.exception(module: module, path: path, message: message)}
  end
end

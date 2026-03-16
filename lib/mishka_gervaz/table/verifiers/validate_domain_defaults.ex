defmodule MishkaGervaz.Table.Verifiers.ValidateDomainDefaults do
  @moduledoc """
  Validates the domain table configuration.

  Ensures:
  - UI adapter module exists (if specified)
  - PubSub module exists (if specified)
  - Pagination settings are valid (page_size, page_size_options, type)
  """

  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  @pagination_path [:mishka_gervaz, :table, :pagination]

  @impl true
  def verify(dsl_state) do
    with :ok <- validate_ui_adapter(dsl_state),
         :ok <- validate_pubsub(dsl_state),
         :ok <- validate_pagination(dsl_state) do
      :ok
    end
  end

  @spec validate_ui_adapter(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_ui_adapter(dsl_state) do
    case Verifier.get_option(dsl_state, [:mishka_gervaz, :table], :ui_adapter) do
      nil ->
        :ok

      adapter when is_atom(adapter) ->
        if Code.ensure_loaded?(adapter) do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             module: Verifier.get_persisted(dsl_state, :module),
             path: [:mishka_gervaz, :table, :ui_adapter],
             message: "UI adapter module #{inspect(adapter)} is not loaded"
           )}
        end

      _ ->
        :ok
    end
  end

  @spec validate_pubsub(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_pubsub(dsl_state) do
    case Verifier.get_option(dsl_state, [:mishka_gervaz, :table, :realtime], :pubsub) do
      nil ->
        :ok

      pubsub when is_atom(pubsub) ->
        if Code.ensure_loaded?(pubsub) do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             module: Verifier.get_persisted(dsl_state, :module),
             path: [:mishka_gervaz, :table, :realtime, :pubsub],
             message: "PubSub module #{inspect(pubsub)} is not loaded"
           )}
        end

      _ ->
        :ok
    end
  end

  @spec validate_pagination(Spark.Dsl.t()) :: :ok | {:error, Spark.Error.DslError.t()}
  defp validate_pagination(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    page_size = Verifier.get_option(dsl_state, @pagination_path, :page_size)

    page_size_options =
      Verifier.get_option(dsl_state, @pagination_path, :page_size_options)

    pagination_type = Verifier.get_option(dsl_state, @pagination_path, :type)

    max_page_size = Verifier.get_option(dsl_state, @pagination_path, :max_page_size)

    with :ok <- validate_page_size(page_size, module),
         :ok <- validate_page_size_options(page_size_options, module),
         :ok <- validate_pagination_type(pagination_type, module),
         :ok <- validate_page_size_in_options(page_size, page_size_options, module),
         :ok <- validate_max_page_size(max_page_size, page_size_options, module) do
      :ok
    end
  end

  defp validate_page_size(nil, _module), do: :ok
  defp validate_page_size(size, _module) when is_integer(size) and size > 0, do: :ok

  defp validate_page_size(size, module) do
    message = """
    page_size must be a positive integer, got: #{inspect(size)}

    Fix: Set a valid page_size in your domain's mishka_gervaz config:

        mishka_gervaz do
          table do
            pagination do
              page_size 20
            end
          end
        end
    """

    dsl_error(module, @pagination_path ++ [:page_size], message)
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

    dsl_error(module, @pagination_path ++ [:page_size_options], message)
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

      dsl_error(module, @pagination_path ++ [:page_size_options], message)
    end
  end

  defp validate_page_size_options(value, module) do
    message = """
    page_size_options must be a list of positive integers, got: #{inspect(value)}

    Fix: Provide a list of page size options:

        pagination do
          page_size_options [20, 50, 100]
        end
    """

    dsl_error(module, @pagination_path ++ [:page_size_options], message)
  end

  defp validate_pagination_type(nil, _module), do: :ok
  defp validate_pagination_type(t, _module) when t in [:numbered, :infinite, :load_more], do: :ok

  defp validate_pagination_type(type, module) do
    message = """
    pagination type must be one of :numbered, :infinite, or :load_more, got: #{inspect(type)}

    Fix: Set a valid pagination type:

        pagination do
          type :numbered
        end
    """

    dsl_error(module, @pagination_path ++ [:type], message)
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

      dsl_error(module, @pagination_path, message)
    end
  end

  defp validate_page_size_in_options(_, _, _), do: :ok

  defp validate_max_page_size(nil, _options, _module), do: :ok

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

      dsl_error(module, @pagination_path ++ [:max_page_size], message)
    end
  end

  defp validate_max_page_size(_, _, _), do: :ok

  defp dsl_error(module, path, message) do
    {:error, Spark.Error.DslError.exception(module: module, path: path, message: message)}
  end
end

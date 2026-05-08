defmodule MishkaGervaz.Form.Web.Events.Helpers do
  @moduledoc """
  Shared helpers for `MishkaGervaz.Form.Web.Events` and its sub-handlers.

  Two reasons these live here rather than inside each sub-handler's
  `__using__` macro:

  1. **Reuse across sub-handlers and user overrides.** A user module that
     overrides `submit/3` (via `use Events.SubmitHandler`) can call any
     helper here without redefining it.
  2. **Smaller compiled bytecode per consumer.** Pure helpers compile
     once in this module rather than into every consumer's beam.

  Three groups:

  - **Typed-param helpers** (`parse_typed_params/2`,
    `sanitize_typed_params/2`) — dispatch through `field.type_module`
    when set; pass through otherwise.
  - **Sanitization helpers** (`sanitize_string/1`,
    `sanitize_list_item/2`) — extracted from `SanitizationHandler`'s
    `__using__` macro.
  - **Upload helpers** (`merge_uploaded_files/4`) — extracted from
    `SubmitHandler`'s `__using__` macro.

  See `MishkaGervaz.Form.Web.Events`,
  `MishkaGervaz.Form.Web.Events.SanitizationHandler`,
  `MishkaGervaz.Form.Web.Events.SubmitHandler`,
  `MishkaGervaz.Form.Web.Events.ValidationHandler`, and the sibling
  sub-handlers.
  """

  @doc false
  @spec parse_typed_params(list(map()), map()) :: map()
  def parse_typed_params(fields, params) when is_list(fields) and is_map(params) do
    Enum.reduce(fields, params, fn field, acc ->
      apply_type_fn(acc, field, :parse_params)
    end)
  end

  def parse_typed_params(_fields, params), do: params

  @doc false
  @spec sanitize_typed_params(list(map()), map()) :: map()
  def sanitize_typed_params(fields, params) when is_list(fields) and is_map(params) do
    Enum.reduce(fields, params, fn field, acc ->
      apply_type_fn(acc, field, :sanitize)
    end)
  end

  def sanitize_typed_params(_fields, params), do: params

  defp apply_type_fn(params, field, fun_name) do
    field_name = to_string(field.name)
    type_mod = Map.get(field, :type_module)

    with {:ok, value} <- Map.fetch(params, field_name),
         true <- not is_nil(type_mod),
         true <- function_exported?(type_mod, fun_name, 2) do
      Map.put(params, field_name, apply(type_mod, fun_name, [value, field]))
    else
      _ -> params
    end
  end

  @doc false
  @spec sanitize_string(any()) :: any()
  def sanitize_string(value) when is_binary(value) do
    value
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()
  end

  def sanitize_string(value), do: value

  @doc false
  @spec sanitize_list_item(any(), (map() -> map())) :: any()
  def sanitize_list_item(item, _sanitize_params_fn) when is_binary(item),
    do: sanitize_string(item)

  def sanitize_list_item(item, sanitize_params_fn) when is_map(item),
    do: sanitize_params_fn.(item)

  def sanitize_list_item(item, _sanitize_params_fn), do: item

  @doc false
  @spec merge_uploaded_files(
          Phoenix.LiveView.Socket.t(),
          map(),
          map(),
          list(map())
        ) :: {Phoenix.LiveView.Socket.t(), map()}
  def merge_uploaded_files(socket, params, _upload_config, []), do: {socket, params}

  def merge_uploaded_files(socket, params, upload_config, uploaded_files) do
    param_key = to_string(upload_config[:field] || upload_config.name)
    {socket, Map.put(params, param_key, uploaded_files)}
  end
end

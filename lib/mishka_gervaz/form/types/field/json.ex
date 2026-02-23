defmodule MishkaGervaz.Form.Types.Field.Json do
  @moduledoc """
  JSON editor field type.
  """

  @behaviour MishkaGervaz.Form.Behaviours.FieldType

  @impl true
  def render(assigns, _config) do
    assigns
  end

  @impl true
  def validate(value, config) when is_map(value) or is_list(value) do
    ash_type = Map.get(config || %{}, :ash_type)

    cond do
      map_type?(ash_type) and not is_map(value) ->
        {:error, "must be a JSON object"}

      array_type?(ash_type) and not is_list(value) ->
        {:error, "must be a JSON array"}

      true ->
        {:ok, value}
    end
  end

  def validate(value, config) when is_binary(value) and value != "" do
    ash_type = Map.get(config || %{}, :ash_type)

    case Jason.decode(value) do
      {:ok, decoded} ->
        cond do
          map_type?(ash_type) and not is_map(decoded) ->
            {:error, "must be a JSON object"}

          array_type?(ash_type) and not is_list(decoded) ->
            {:error, "must be a JSON array"}

          true ->
            {:ok, value}
        end

      {:error, _} ->
        {:error, "must be valid JSON"}
    end
  end

  def validate(value, _config), do: {:ok, value}

  defp map_type?(:map), do: true
  defp map_type?(Ash.Type.Map), do: true
  defp map_type?(_), do: false

  defp array_type?({:array, _}), do: true
  defp array_type?(_), do: false

  @impl true
  def parse_params(value, _config) when is_binary(value) and value != "" do
    case Jason.decode(value) do
      {:ok, parsed} -> parsed
      {:error, _} -> value
    end
  end

  def parse_params(value, _config), do: value

  @impl true
  def sanitize(value, _config), do: value

  @impl true
  def default_ui, do: %{type: :json}
end

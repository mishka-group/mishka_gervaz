defmodule MishkaGervaz.Form.Web.UploadHelpers do
  @moduledoc """
  Shared utility functions for file upload wiring in MishkaGervaz forms.

  Provides helpers to:
  - Build `allow_upload/3` options from DSL config
  - Generate namespaced upload names to avoid collisions
  - Parse accept strings
  - Check if a form config has uploads
  """

  @doc """
  Parse an accept string into a list of MIME types / extensions.

  Returns `:any` if nil, or a list of trimmed parts.

  ## Examples

      iex> parse_accept(nil)
      :any

      iex> parse_accept("image/*,.pdf")
      ["image/*", ".pdf"]
  """
  @spec parse_accept(String.t() | nil) :: :any | list(String.t())
  def parse_accept(nil), do: :any

  def parse_accept(accept) when is_binary(accept) do
    accept
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Build keyword options for `Phoenix.LiveView.allow_upload/3` from a DSL upload config map.

  ## Examples

      iex> build_allow_upload_opts(%{accept: "image/*", max_entries: 3, max_file_size: 10_000_000, auto_upload: true}, "my-form")
      [accept: ~w(image/*), max_entries: 3, max_file_size: 10_000_000, auto_upload: true]
  """
  @spec build_allow_upload_opts(map(), String.t()) :: keyword()
  def build_allow_upload_opts(upload_config, _component_id) do
    [
      max_entries: upload_config[:max_entries] || 1,
      max_file_size: upload_config[:max_file_size] || 8_000_000,
      auto_upload: upload_config[:auto_upload] || false
    ]
    |> maybe_put_opt(:accept, upload_config[:accept], &parse_accept_to_opt/1)
    |> maybe_put_opt(:chunk_size, upload_config[:chunk_size])
    |> maybe_put_opt(:chunk_timeout, upload_config[:chunk_timeout])
    |> maybe_put_opt(:external, upload_config[:external])
    |> maybe_put_opt(:writer, upload_config[:writer])
  end

  @doc """
  Generate a namespaced upload name unique per component instance.

  This avoids collisions when multiple form components are on the same page.

  ## Examples

      iex> namespaced_upload_name(:avatar, "post-form")
      :avatar_post_form
  """
  @spec namespaced_upload_name(atom(), String.t()) :: atom()
  def namespaced_upload_name(upload_name, component_id) do
    safe_id =
      component_id
      |> to_string()
      |> String.replace(~r/[^a-zA-Z0-9_]/, "_")

    String.to_atom("#{upload_name}_#{safe_id}")
  end

  @doc """
  Check if a Static config struct has any uploads configured.
  """
  @spec has_uploads?(map()) :: boolean()
  def has_uploads?(%{uploads: uploads}) when is_list(uploads) and uploads != [], do: true
  def has_uploads?(_), do: false

  @doc """
  Find the upload config for a given field name.

  Matches by `field` first, then by `name`.
  """
  @spec find_upload_for_field(map(), atom()) :: map() | nil
  def find_upload_for_field(%{uploads: uploads}, field_name) when is_list(uploads) do
    Enum.find(uploads, fn u -> u[:field] == field_name end) ||
      Enum.find(uploads, fn u -> u[:name] == field_name end)
  end

  def find_upload_for_field(_, _), do: nil

  @doc """
  Convert an upload error atom to a human-readable string.
  """
  @spec upload_error_to_string(atom()) :: String.t()
  def upload_error_to_string(:too_large), do: "File is too large"
  def upload_error_to_string(:too_many_files), do: "Too many files"
  def upload_error_to_string(:not_accepted), do: "File type not accepted"
  def upload_error_to_string(:external_client_failure), do: "Upload failed"
  def upload_error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_put_opt(opts, _key, nil, _transform), do: opts
  defp maybe_put_opt(opts, key, value, transform), do: Keyword.put(opts, key, transform.(value))

  defp parse_accept_to_opt(accept) when is_binary(accept) do
    accept
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_accept_to_opt(accept), do: accept
end

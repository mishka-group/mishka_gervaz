defmodule MishkaGervaz.Form.Web.DataLoader.Helpers do
  @moduledoc """
  Shared helpers for `MishkaGervaz.Form.Web.DataLoader`.

  Two reasons these live outside the `__using__` macro:

  1. **Reuse across the macro and user overrides.** A user module that
     overrides `load_record/3` (via `use MishkaGervaz.Form.Web.DataLoader`)
     can call any helper here without redefining it.
  2. **Smaller compiled bytecode per consumer.** Each `use` injects
     ~150 lines of pure-data helpers — extracting them means they
     compile once in this module rather than into every consumer's
     beam.

  Three functional groups:

  - **Field lookups & extraction** (`find_field/2`,
    `extract_existing_files/2`, `extract_dependency_values/2`,
    `extract_defaults_to_field_values/1`) — pure reads off `State` /
    `Phoenix.HTML.Form`.
  - **File normalization** (`normalize_file_list/1`,
    `normalize_file_info/1`) — coerce upload payloads into
    `%{filename: …}` maps.
  - **Coordination** (`load_dependent_relations/3`,
    `load_readonly_relation_options/3`) — dispatch through a
    consumer-supplied function or module so `defoverridable`
    semantics are preserved.

  See `MishkaGervaz.Form.Web.DataLoader`,
  `MishkaGervaz.Form.Web.DataLoader.RecordLoader`,
  `MishkaGervaz.Form.Web.DataLoader.RelationLoader`,
  `MishkaGervaz.Form.Web.DataLoader.TenantResolver`,
  `MishkaGervaz.Form.Web.DataLoader.HookRunner`, and
  `MishkaGervaz.Form.Web.State`.
  """

  alias MishkaGervaz.Form.Web.State

  @doc false
  @spec find_field(State.t(), atom()) :: map() | nil
  def find_field(state, field_name) do
    Enum.find(state.static.fields, &(&1.name == field_name))
  end

  @doc false
  @spec extract_existing_files(State.t(), Phoenix.HTML.Form.t()) ::
          %{atom() => list(map())}
  def extract_existing_files(%{static: %{uploads: uploads}}, form)
      when is_list(uploads) and uploads != [] do
    extract_from_record(uploads, form)
  end

  def extract_existing_files(_state, _form), do: %{}

  defp extract_from_record(uploads, %{source: %{source: %{data: record}}})
       when not is_nil(record) do
    Map.new(uploads, fn upload_config ->
      files = read_existing_files(upload_config, record)
      {upload_config.name, normalize_file_list(files)}
    end)
  end

  defp extract_from_record(_uploads, _form), do: %{}

  defp read_existing_files(upload_config, record) do
    case upload_config[:existing] do
      nil ->
        field = upload_config[:field] || upload_config.name
        Map.get(record, field)

      field_name when is_atom(field_name) ->
        Map.get(record, field_name)

      fun when is_function(fun, 1) ->
        fun.(record)

      _ ->
        nil
    end
  end

  @doc false
  @spec normalize_file_list(any()) :: list(map())
  def normalize_file_list(nil), do: []
  def normalize_file_list(value) when is_binary(value), do: [%{filename: value}]
  def normalize_file_list(value) when is_list(value), do: Enum.map(value, &normalize_file_info/1)
  def normalize_file_list(value) when is_map(value), do: [normalize_file_info(value)]
  def normalize_file_list(_), do: []

  @doc false
  @spec normalize_file_info(any()) :: map()
  def normalize_file_info(%{filename: _} = file), do: file
  def normalize_file_info(%{name: name} = file), do: Map.put(file, :filename, name)

  def normalize_file_info(%{"filename" => filename} = file),
    do: %{filename: filename, id: file["id"]}

  def normalize_file_info(%{"name" => name} = file), do: %{filename: name, id: file["id"]}
  def normalize_file_info(value) when is_binary(value), do: %{filename: value}
  def normalize_file_info(other), do: %{filename: inspect(other)}

  @doc false
  @spec extract_dependency_values(State.t(), Phoenix.HTML.Form.t()) :: map()
  def extract_dependency_values(state, form) do
    case form do
      %{source: %{source: %{data: data}}} when not is_nil(data) -> do_extract_deps(state, data)
      _ -> %{}
    end
  end

  defp do_extract_deps(state, record) do
    derive_fns =
      state.static.fields
      |> Enum.filter(&(not is_nil(&1[:derive_value])))
      |> Map.new(&{&1.name, &1.derive_value})

    state.static.fields
    |> Enum.flat_map(&dep_names/1)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn field_name, acc ->
      record
      |> Map.get(field_name)
      |> resolve_value(field_name, derive_fns, record)
      |> case do
        nil -> acc
        "" -> acc
        value -> Map.put(acc, field_name, value)
      end
    end)
  end

  defp dep_names(%{type: :relation, name: name, depends_on: nil}), do: [name]
  defp dep_names(%{type: :relation, name: name, depends_on: dep}), do: [name, dep]
  defp dep_names(%{depends_on: nil}), do: []
  defp dep_names(%{depends_on: dep}), do: [dep]
  defp dep_names(_), do: []

  defp resolve_value(nil, field_name, derive_fns, record) do
    case Map.get(derive_fns, field_name) do
      nil -> nil
      derive_fn -> derive_fn.(record)
    end
  end

  defp resolve_value(value, _field_name, _derive_fns, _record), do: value

  @doc false
  @spec extract_defaults_to_field_values(State.t()) :: map()
  def extract_defaults_to_field_values(%{defaults: defaults})
      when is_map(defaults) and defaults != %{} do
    defaults
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

  def extract_defaults_to_field_values(_state), do: %{}

  @doc false
  @spec run_on_init_hook(State.t(), Phoenix.HTML.Form.t()) :: Phoenix.HTML.Form.t()
  def run_on_init_hook(%{static: %{hooks: %{on_init: on_init}}} = state, form)
      when is_function(on_init, 2) do
    case on_init.(form, state) do
      %Phoenix.HTML.Form{} = modified_form -> modified_form
      _ -> form
    end
  end

  def run_on_init_hook(_state, form), do: form

  @doc false
  @spec field_readonly?(map(), State.t()) :: boolean()
  def field_readonly?(%{readonly: f}, state) when is_function(f, 1), do: f.(state)
  def field_readonly?(%{readonly: true}, _state), do: true
  def field_readonly?(_field, _state), do: false

  @doc false
  @spec load_dependent_relations(
          Phoenix.LiveView.Socket.t(),
          State.t(),
          (Phoenix.LiveView.Socket.t(), State.t(), atom() -> Phoenix.LiveView.Socket.t())
        ) :: Phoenix.LiveView.Socket.t()
  def load_dependent_relations(socket, state, load_fn) when is_function(load_fn, 3) do
    state.static.fields
    |> Enum.filter(fn field ->
      field.depends_on != nil and
        Map.has_key?(state.field_values, field.depends_on) and
        field.type == :relation
    end)
    |> Enum.reduce(socket, fn field, acc -> load_fn.(acc, state, field.name) end)
  end

  @doc false
  @spec load_readonly_relation_options(
          Phoenix.LiveView.Socket.t(),
          State.t(),
          module()
        ) :: Phoenix.LiveView.Socket.t()
  def load_readonly_relation_options(socket, original_state, relation_mod) do
    original_state.static.fields
    |> Enum.filter(fn field ->
      field.type == :relation and
        field_readonly?(field, original_state) and
        Map.has_key?(original_state.field_values, field.name)
    end)
    |> Enum.reduce(socket, &resolve_readonly_field(&1, &2, original_state, relation_mod))
  end

  defp resolve_readonly_field(field, socket, original_state, relation_mod) do
    value = Map.get(original_state.field_values, field.name)
    ids = if is_list(value), do: Enum.map(value, &to_string/1), else: [to_string(value)]

    case relation_mod.resolve_selected(field, original_state, ids) do
      {:ok, resolved} when resolved != [] ->
        merge_readonly_options(socket, field.name, resolved)

      _ ->
        socket
    end
  end

  defp merge_readonly_options(socket, field_name, resolved) do
    current_state = socket.assigns.form_state
    current_opts = Map.get(current_state.relation_options, field_name, %{})

    new_opts =
      Map.merge(current_opts, %{
        options: resolved,
        selected_options: resolved,
        loading?: false
      })

    relation_options = Map.put(current_state.relation_options, field_name, new_opts)

    Phoenix.Component.assign(
      socket,
      :form_state,
      State.update(current_state, relation_options: relation_options)
    )
  end
end

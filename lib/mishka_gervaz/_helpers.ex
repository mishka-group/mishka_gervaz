defmodule MishkaGervaz.Helpers do
  @moduledoc """
  Shared helper functions for MishkaGervaz.
  """

  use Phoenix.Component

  @doc """
  Dynamic component wrapper using apply/3 for proper Phoenix lifecycle.
  See: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#module-dynamic-component-rendering
  """
  @spec dynamic_component(map()) :: Phoenix.LiveView.Rendered.t()
  def dynamic_component(assigns) do
    {mod, assigns} = Map.pop(assigns, :module)
    {func, assigns} = Map.pop(assigns, :function)
    apply(mod, func, [normalize_html_attrs(assigns)])
  end

  defp normalize_html_attrs(assigns) do
    Enum.reduce(assigns, assigns, fn
      {key, value}, acc when is_atom(key) ->
        str = Atom.to_string(key)

        if String.starts_with?(str, "phx_") or String.starts_with?(str, "data_") do
          dashed = str |> String.replace("_", "-") |> String.to_atom()
          acc |> Map.delete(key) |> Map.put(dashed, value)
        else
          acc
        end

      {_, _}, acc ->
        acc
    end)
  end

  @doc """
  Converts an atom or string to a human-readable label.

  ## Examples

      iex> MishkaGervaz.Helpers.humanize(:first_name)
      "First Name"

      iex> MishkaGervaz.Helpers.humanize(:user_id)
      "User Id"

      iex> MishkaGervaz.Helpers.humanize("already_formatted")
      "already_formatted"
  """
  @spec humanize(atom() | String.t()) :: String.t()
  def humanize(atom) when is_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def humanize(string) when is_binary(string), do: string

  @doc """
  Resolves a label that may be a string or a zero-arity function.

  This enables i18n support in DSL labels by allowing users to pass
  `fn -> gettext("...") end` which defers execution to runtime.

  ## Examples

      iex> MishkaGervaz.Helpers.resolve_label("Static Label")
      "Static Label"

      iex> MishkaGervaz.Helpers.resolve_label(fn -> "Dynamic Label" end)
      "Dynamic Label"

      iex> MishkaGervaz.Helpers.resolve_label(nil)
      nil
  """
  @spec resolve_label(String.t() | (-> String.t()) | nil) :: String.t() | nil
  def resolve_label(label) when is_function(label, 0), do: label.()
  def resolve_label(label) when is_binary(label), do: label
  def resolve_label(nil), do: nil

  @doc """
  Resolves a display value from a record using either an atom field or a function.

  Supports:
  - 2-arity: `resolve_label(record, display_field)` - for atom or 1-arity function
  - 3-arity: `resolve_label(record, display_field, state)` - for 2-arity function

  ## Examples

      iex> MishkaGervaz.Helpers.resolve_label(%{name: "Test"}, :name)
      "Test"

      iex> MishkaGervaz.Helpers.resolve_label(%{name: "Cat", site: %{name: "Site1"}}, fn r -> "\#{r.name} - \#{r.site.name}" end)
      "Cat - Site1"

      iex> MishkaGervaz.Helpers.resolve_label(%{id: 123, name: nil}, :name)
      "123"
  """
  @spec resolve_label(
          struct(),
          atom() | (struct() -> String.t()) | (struct(), map() -> String.t())
        ) ::
          String.t()
  def resolve_label(record, display_field) when is_function(display_field, 1) do
    display_field.(record)
  end

  def resolve_label(record, display_field) when is_atom(display_field) do
    case Map.get(record, display_field) do
      nil -> to_string(record.id)
      value -> to_string(value)
    end
  end

  @spec resolve_label(struct(), (struct(), map() -> String.t()), map()) :: String.t()
  def resolve_label(record, display_field, state) when is_function(display_field, 2) do
    display_field.(record, state)
  end

  def resolve_label(record, display_field, _state) when is_function(display_field, 1) do
    display_field.(record)
  end

  def resolve_label(record, display_field, _state) when is_atom(display_field) do
    case Map.get(record, display_field) do
      nil -> to_string(record.id)
      value -> to_string(value)
    end
  end

  @doc """
  Resolves a label from a nested UI structure.

  Extracts the label from entities that have a `ui` field containing a `label`.
  Supports both map and struct formats, with labels that can be strings or
  zero-arity functions (for i18n support).

  ## Examples

      iex> MishkaGervaz.Helpers.resolve_ui_label(%{ui: %{label: "Name"}})
      "Name"

      iex> MishkaGervaz.Helpers.resolve_ui_label(%{ui: %{label: fn -> "Dynamic" end}})
      "Dynamic"

      iex> MishkaGervaz.Helpers.resolve_ui_label(%{ui: nil})
      nil

      iex> MishkaGervaz.Helpers.resolve_ui_label(%{other: "field"})
      nil

      iex> MishkaGervaz.Helpers.resolve_ui_label(nil)
      nil
  """
  @spec resolve_ui_label(map() | struct() | nil) :: String.t() | nil
  def resolve_ui_label(%{ui: %{label: label}}) when is_function(label, 0), do: label.()
  def resolve_ui_label(%{ui: %{label: label}}) when is_binary(label), do: label
  def resolve_ui_label(%{ui: ui}) when is_struct(ui), do: resolve_label(Map.get(ui, :label))
  def resolve_ui_label(_), do: nil

  @doc """
  Extracts and resolves a label from a UI structure, with fallback to humanized name.

  Similar to `resolve_ui_label/1` but falls back to humanizing the `:name` field
  when no UI label is found.

  ## Examples

      iex> MishkaGervaz.Helpers.get_ui_label(%{ui: %{label: "Custom"}, name: :field})
      "Custom"

      iex> MishkaGervaz.Helpers.get_ui_label(%{name: :user_name})
      "User Name"

      iex> MishkaGervaz.Helpers.get_ui_label(%{ui: nil, name: :created_at})
      "Created At"
  """
  @spec get_ui_label(map() | struct()) :: String.t()
  def get_ui_label(entity) do
    resolve_ui_label(entity) || humanize(entity[:name] || entity.name)
  end

  @doc """
  Resolves options that may be a list or a zero-arity function returning a list.

  This enables dynamic options (e.g., from a database query) in DSL fields by
  allowing users to pass `fn -> query_options() end` which defers execution to runtime.

  ## Examples

      iex> MishkaGervaz.Helpers.resolve_options([{"A", "a"}, {"B", "b"}])
      [{"A", "a"}, {"B", "b"}]

      iex> MishkaGervaz.Helpers.resolve_options(fn -> [{"X", "x"}] end)
      [{"X", "x"}]

      iex> MishkaGervaz.Helpers.resolve_options(nil)
      []
  """
  @spec resolve_options(list() | (-> list()) | nil) :: list()
  def resolve_options(opts) when is_function(opts, 0), do: opts.()
  def resolve_options(opts) when is_list(opts), do: opts
  def resolve_options(_), do: []

  @doc """
  Normalizes a list of options for HTML select elements.

  Converts various option formats to `{label, value}` tuples with string values,
  ensuring compatibility with Phoenix HTML attributes.

  ## Examples

      iex> MishkaGervaz.Helpers.normalize_options([{"API Only", :api_only}, {"Hybrid", :hybrid}])
      [{"API Only", "api_only"}, {"Hybrid", "hybrid"}]

      iex> MishkaGervaz.Helpers.normalize_options([:active, :inactive])
      [{"Active", "active"}, {"Inactive", "inactive"}]

      iex> MishkaGervaz.Helpers.normalize_options(["foo", "bar"])
      [{"foo", "foo"}, {"bar", "bar"}]

      iex> MishkaGervaz.Helpers.normalize_options(nil)
      []
  """
  @spec normalize_options(list() | nil) :: [{String.t(), String.t()}]
  def normalize_options(nil), do: []
  def normalize_options(options) when is_list(options), do: Enum.map(options, &normalize_option/1)
  def normalize_options(_), do: []

  @spec normalize_option({any(), any()} | atom() | any()) :: {String.t(), String.t()}
  defp normalize_option({label, value}),
    do: {to_string(label), to_string(value)}

  defp normalize_option(value) when is_atom(value),
    do: {humanize(value), to_string(value)}

  defp normalize_option(value),
    do: {to_string(value), to_string(value)}

  @doc """
  Converts string boolean representations to actual booleans.

  Safely handles values coming from URL params, form inputs, or other
  string-based sources. Follows Phoenix's `normalize_value/2` pattern.

  ## Examples

      iex> MishkaGervaz.Helpers.to_boolean("true")
      true

      iex> MishkaGervaz.Helpers.to_boolean("false")
      false

      iex> MishkaGervaz.Helpers.to_boolean(true)
      true

      iex> MishkaGervaz.Helpers.to_boolean(nil)
      nil

      iex> MishkaGervaz.Helpers.to_boolean("")
      nil
  """
  @spec to_boolean(String.t() | boolean() | nil) :: boolean() | nil
  def to_boolean("true"), do: true
  def to_boolean("false"), do: false
  def to_boolean(true), do: true
  def to_boolean(false), do: false
  def to_boolean(nil), do: nil
  def to_boolean(""), do: nil
  def to_boolean(_), do: nil

  @doc """
  Puts a key-value pair into a map only if the value is present and valid.

  Designed for building configuration maps where optional values should only
  be included when explicitly set. Supports multiple input formats commonly
  used with Spark DSL introspection functions.

  ## Supported Formats

  - `{:ok, value}` - Spark/Ash introspection result (value must not be nil)
  - `{:error, _}` - Ignored, returns original map
  - `:error` - Ignored, returns original map
  - Direct value - Added if not nil

  ## Examples

      iex> %{} |> MishkaGervaz.Helpers.map_put_if_set(:name, {:ok, "John"})
      %{name: "John"}

      iex> %{} |> MishkaGervaz.Helpers.map_put_if_set(:name, {:ok, nil})
      %{}

      iex> %{} |> MishkaGervaz.Helpers.map_put_if_set(:name, :error)
      %{}

      iex> %{} |> MishkaGervaz.Helpers.map_put_if_set(:name, {:error, :not_found})
      %{}

      iex> %{} |> MishkaGervaz.Helpers.map_put_if_set(:name, "John")
      %{name: "John"}

      iex> %{} |> MishkaGervaz.Helpers.map_put_if_set(:name, nil)
      %{}

      iex> %{a: 1} |> MishkaGervaz.Helpers.map_put_if_set(:b, {:ok, 2}) |> MishkaGervaz.Helpers.map_put_if_set(:c, {:ok, 3})
      %{a: 1, b: 2, c: 3}
  """
  @spec map_put_if_set(map(), atom(), {:ok, any()} | {:error, any()} | :error | any()) :: map()
  def map_put_if_set(map, key, {:ok, value}) when not is_nil(value), do: Map.put(map, key, value)
  def map_put_if_set(map, _key, {:ok, nil}), do: map
  def map_put_if_set(map, _key, {:error, _}), do: map
  def map_put_if_set(map, _key, :error), do: map
  def map_put_if_set(map, key, value) when not is_nil(value), do: Map.put(map, key, value)
  def map_put_if_set(map, _key, nil), do: map

  @doc """
  Converts a module name to its snake_case short name.

  Takes the last part of a module name and converts it to snake_case.
  Optionally appends a suffix.

  ## Examples

      iex> MishkaGervaz.Helpers.module_to_snake(MyApp.Users.User)
      "user"

      iex> MishkaGervaz.Helpers.module_to_snake(MyApp.BlogPost)
      "blog_post"

      iex> MishkaGervaz.Helpers.module_to_snake(MyApp.Users.User, "_stream")
      "user_stream"

      iex> MishkaGervaz.Helpers.module_to_snake(MyApp.BlogPost, "_table")
      "blog_post_table"
  """
  @spec module_to_snake(module(), String.t()) :: String.t()
  def module_to_snake(module, suffix \\ "") do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(suffix)
  end

  @doc """
  Conditionally assigns a key-value pair to assigns only if the value is not nil.

  This is useful when building assigns for components where you want to allow
  upstream defaults (via `assign_new`) to take effect when no value is provided.

  ## Examples

      iex> %{} |> Phoenix.Component.assign(:foo, "bar") |> MishkaGervaz.Helpers.maybe_assign(:icon, nil)
      %{foo: "bar"}

      iex> %{} |> Phoenix.Component.assign(:foo, "bar") |> MishkaGervaz.Helpers.maybe_assign(:icon, "hero-trash")
      %{foo: "bar", icon: "hero-trash"}
  """
  @spec maybe_assign(map(), atom(), any()) :: map()
  def maybe_assign(assigns, _key, nil), do: assigns
  def maybe_assign(assigns, key, value), do: assign(assigns, key, value)

  @doc """
  Normalizes selected values for multi-select components.

  Converts various input formats to a list of non-empty string values,
  filtering out empty strings and "nil" string representations.

  ## Examples

      iex> MishkaGervaz.Helpers.normalize_selected_values(nil)
      []

      iex> MishkaGervaz.Helpers.normalize_selected_values(["a", "b", "c"])
      ["a", "b", "c"]

      iex> MishkaGervaz.Helpers.normalize_selected_values([:foo, :bar])
      ["foo", "bar"]

      iex> MishkaGervaz.Helpers.normalize_selected_values(["valid", "", nil, "nil"])
      ["valid"]

      iex> MishkaGervaz.Helpers.normalize_selected_values("single")
      ["single"]
  """
  @spec normalize_selected_values(list() | any() | nil) :: [String.t()]
  def normalize_selected_values(nil), do: []

  def normalize_selected_values(values) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == "" or &1 == "nil"))
  end

  def normalize_selected_values(value), do: [to_string(value)]

  @doc """
  Checks if a string name is a known entity name in the given state.

  Pattern matches on the state structure to auto-detect the context:
  - Form state (`static.fields`) — checks field names
  - Table state (`static.columns`) — checks column names
  - Table state (`static.filters`) — checks filter names (with explicit `:filters`)
  - Form state (`static.steps`) — checks step names (with explicit `:steps`)
  - Form state (`static.uploads`) — checks upload names (with explicit `:uploads`)

  Avoids `String.to_existing_atom/1` and rescue blocks for safe user input validation.

  ## Examples

      iex> state = %{static: %{fields: [%{name: :title}, %{name: :tags}]}}
      iex> MishkaGervaz.Helpers.known_name?("tags", state)
      true

      iex> MishkaGervaz.Helpers.known_name?("unknown", state)
      false

      iex> state = %{static: %{columns: [%{name: :id}, %{name: :status}]}}
      iex> MishkaGervaz.Helpers.known_name?("status", state)
      true
  """
  @spec known_name?(String.t(), map()) :: boolean()
  def known_name?(name, %{static: %{fields: fields}}) when is_binary(name) and is_list(fields) do
    name_in_entities?(name, fields)
  end

  def known_name?(name, %{static: %{columns: columns}})
      when is_binary(name) and is_list(columns) do
    name_in_entities?(name, columns)
  end

  def known_name?(_, _), do: false

  @spec known_name?(String.t(), map(), :filters | :steps | :uploads) :: boolean()
  def known_name?(name, %{static: static}, kind)
      when is_binary(name) and kind in [:filters, :steps, :uploads] do
    case Map.get(static, kind) do
      list when is_list(list) -> name_in_entities?(name, list)
      _ -> false
    end
  end

  def known_name?(_, _, _), do: false

  defp name_in_entities?(name, entities),
    do: Enum.any?(entities, &(Atom.to_string(&1.name) == name))

  @doc """
  Checks if a value is present (not nil, empty string, or empty list).

  ## Examples

      iex> MishkaGervaz.Helpers.has_value?(nil)
      false

      iex> MishkaGervaz.Helpers.has_value?("")
      false

      iex> MishkaGervaz.Helpers.has_value?([])
      false

      iex> MishkaGervaz.Helpers.has_value?("test")
      true

      iex> MishkaGervaz.Helpers.has_value?(["a", "b"])
      true
  """
  @spec has_value?(any()) :: boolean()
  def has_value?(nil), do: false
  def has_value?(""), do: false
  def has_value?([]), do: false
  def has_value?(_), do: true

  @doc """
  Checks if an entity (filter, action, etc.) is accessible based on visibility and restrictions.

  Handles:
  - `restricted: true` with non-master user → not accessible
  - `visible: false` → not accessible
  - `visible: fn state -> boolean end` → calls function

  ## Examples

      iex> MishkaGervaz.Helpers.accessible?(%{restricted: true}, %{master_user?: false})
      false

      iex> MishkaGervaz.Helpers.accessible?(%{restricted: true}, %{master_user?: true})
      true

      iex> MishkaGervaz.Helpers.accessible?(%{visible: false}, %{})
      false

      iex> MishkaGervaz.Helpers.accessible?(%{visible: true}, %{})
      true
  """
  @spec accessible?(map(), map()) :: boolean()
  def accessible?(%{restricted: true}, %{master_user?: false}), do: false
  def accessible?(%{visible: visible}, state) when is_function(visible, 1), do: visible.(state)
  def accessible?(%{visible: false}, _state), do: false
  def accessible?(_, _), do: true

  @doc """
  Finds an entity in a list by its name field.

  ## Examples

      iex> MishkaGervaz.Helpers.find_by_name([%{name: :foo}, %{name: :bar}], :bar)
      %{name: :bar}

      iex> MishkaGervaz.Helpers.find_by_name([%{name: :foo}], :missing)
      nil

      iex> MishkaGervaz.Helpers.find_by_name(nil, :foo)
      nil
  """
  @spec find_by_name(list() | nil, atom()) :: map() | nil
  def find_by_name(list, name) when is_list(list), do: Enum.find(list, &(&1.name == name))
  def find_by_name(_, _), do: nil

  @doc """
  Formats a file size in bytes to a human-readable string.

  ## Examples

      iex> MishkaGervaz.Helpers.format_filesize(500)
      "500 B"

      iex> MishkaGervaz.Helpers.format_filesize(1024)
      "1.0 KB"

      iex> MishkaGervaz.Helpers.format_filesize(1048576)
      "1.0 MB"

      iex> MishkaGervaz.Helpers.format_filesize(nil)
      "-"
  """
  @spec format_filesize(integer() | nil) :: String.t()
  def format_filesize(size) when is_integer(size) do
    cond do
      size < 1024 -> "#{size} B"
      size < 1024 * 1024 -> "#{Float.round(size / 1024, 1)} KB"
      size < 1024 * 1024 * 1024 -> "#{Float.round(size / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  def format_filesize(_), do: "-"

  @doc """
  Injects preload alias values into a record or list of records.

  When using master/tenant preload patterns (e.g., `master_media_category` aliased to
  `media_category`), this function copies the loaded relationship data from the source
  field to the alias field.

  ## Examples

      iex> record = %{id: 1, master_media_category: %{name: "Photos"}}
      iex> MishkaGervaz.Helpers.inject_preload_aliases(record, %{media_category: :master_media_category})
      %{id: 1, master_media_category: %{name: "Photos"}, media_category: %{name: "Photos"}}

      iex> MishkaGervaz.Helpers.inject_preload_aliases([%{id: 1, source: "val"}], %{alias: :source})
      [%{id: 1, source: "val", alias: "val"}]

      iex> MishkaGervaz.Helpers.inject_preload_aliases(%{id: 1}, nil)
      %{id: 1}

      iex> MishkaGervaz.Helpers.inject_preload_aliases(%{id: 1}, %{})
      %{id: 1}
  """
  @spec inject_preload_aliases(struct() | list(struct()), map() | nil) ::
          struct() | list(struct())
  def inject_preload_aliases(record_or_records, nil), do: record_or_records

  def inject_preload_aliases(record_or_records, aliases) when map_size(aliases) == 0,
    do: record_or_records

  def inject_preload_aliases(records, aliases) when is_list(records) do
    Enum.map(records, &inject_preload_aliases_single(&1, aliases))
  end

  def inject_preload_aliases(record, aliases) do
    inject_preload_aliases_single(record, aliases)
  end

  defp inject_preload_aliases_single(record, aliases) do
    Enum.reduce(aliases, record, fn {alias_key, source_key}, acc ->
      Map.put(acc, alias_key, Map.get(acc, source_key))
    end)
  end

  @doc """
  Invalidates dependent filter values and relation_filter_state when parent filters change.

  Compares old vs new filter values to find changed parents, then recursively finds
  all children whose `depends_on` points to a changed filter. Removes those children
  from both `filter_values` and `relation_filter_state`.

  Returns `{cleaned_filter_values, cleaned_relation_filter_state}`.

  ## Examples

      iex> filters = [%{name: :region, depends_on: nil}, %{name: :city, depends_on: :region}]
      iex> old = %{region: "us", city: "ny"}
      iex> new = %{region: "eu", city: "ny"}
      iex> state = %{static: %{filters: filters}, relation_filter_state: %{}}
      iex> {cleaned_fv, cleaned_rfs} = MishkaGervaz.Helpers.invalidate_dependents(new, old, state)
      iex> cleaned_fv
      %{region: "eu"}
  """
  @spec invalidate_dependents(map(), map(), map()) :: {map(), map()}
  def invalidate_dependents(new_filter_values, old_filter_values, state) do
    filters = state.static.filters
    relation_filter_state = state.relation_filter_state || %{}

    changed_parents =
      Enum.reduce(filters, MapSet.new(), fn filter, acc ->
        name = filter.name
        old_val = Map.get(old_filter_values, name)
        new_val = Map.get(new_filter_values, name)

        if old_val != new_val do
          MapSet.put(acc, name)
        else
          acc
        end
      end)

    if MapSet.size(changed_parents) == 0 do
      {new_filter_values, relation_filter_state}
    else
      all_dependents = find_all_dependents(changed_parents, filters)

      cleaned_filter_values = Map.drop(new_filter_values, MapSet.to_list(all_dependents))
      cleaned_relation_state = Map.drop(relation_filter_state, MapSet.to_list(all_dependents))

      {cleaned_filter_values, cleaned_relation_state}
    end
  end

  @spec find_all_dependents(MapSet.t(), list()) :: MapSet.t()
  defp find_all_dependents(changed_parents, filters) do
    direct_children =
      Enum.reduce(filters, MapSet.new(), fn filter, acc ->
        if filter.depends_on && MapSet.member?(changed_parents, filter.depends_on) do
          MapSet.put(acc, filter.name)
        else
          acc
        end
      end)

    new_dependents = MapSet.difference(direct_children, changed_parents)

    if MapSet.size(new_dependents) == 0 do
      direct_children
    else
      grandchildren = find_all_dependents(MapSet.union(changed_parents, direct_children), filters)
      MapSet.union(direct_children, grandchildren)
    end
  end

  @doc """
  Validates a form and returns per-field errors for the currently-changing field only.

  Designed for use in `on_validate` hooks to provide live inline errors without
  showing unrelated required-field errors for untouched fields.

  Extracts `_target` from `params` to identify the current field, validates via
  `AshPhoenix.Form.validate/3`, then filters errors to only that field.

  Returns `{params, errors}` ready to return directly from an `on_validate` hook.

  ## Examples

      hooks do
        on_validate fn params, state ->
          MishkaGervaz.Helpers.validate_field_errors(state.form.source, params)
        end
      end

      # With param mutation before validation:
      hooks do
        on_validate fn params, state ->
          updated = put_in(params, ["form", "slug"], slugify(params["form"]["title"]))
          MishkaGervaz.Helpers.validate_field_errors(state.form.source, updated)
        end
      end
  """
  @spec validate_field_errors(AshPhoenix.Form.t(), map(), map() | nil) :: {map(), map()}
  def validate_field_errors(ash_form, params, current_errors \\ %{}) do
    current_errors = current_errors || %{}
    target = Map.get(params, "_target")

    target_field =
      case target do
        [_ | rest] when rest != [] -> List.last(rest)
        _ -> nil
      end

    validated =
      AshPhoenix.Form.validate(ash_form, Map.get(params, "form", params), target: target)

    field_errors =
      validated
      |> AshPhoenix.Form.errors(format: :simple)
      |> Enum.filter(fn {field, _} -> to_string(field) == target_field end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    errors =
      cond do
        is_nil(target_field) -> current_errors
        map_size(field_errors) > 0 -> Map.merge(current_errors, field_errors)
        true -> Map.reject(current_errors, fn {field, _} -> to_string(field) == target_field end)
      end

    {params, errors}
  end

  @doc """
  Filters columns based on their visibility setting.

  Evaluates the `visible` field of each column:
  - Function with arity 1: calls with state and uses the result
  - Boolean: uses the value directly
  - Any other value: defaults to true (visible)

  ## Examples

      iex> columns = [%{name: :id, visible: true}, %{name: :secret, visible: false}]
      iex> MishkaGervaz.Helpers.get_visible_columns(columns, %{})
      [%{name: :id, visible: true}]

      iex> columns = [%{name: :admin_only, visible: fn state -> state.master_user? end}]
      iex> MishkaGervaz.Helpers.get_visible_columns(columns, %{master_user?: true})
      [%{name: :admin_only, visible: _}]

      iex> MishkaGervaz.Helpers.get_visible_columns(columns, %{master_user?: false})
      []
  """
  @spec get_visible_columns(list(map()), map()) :: list(map())
  def get_visible_columns(columns, state) do
    Enum.filter(columns, fn column ->
      case column.visible do
        func when is_function(func, 1) -> func.(state)
        val when is_boolean(val) -> val
        _ -> true
      end
    end)
  end

  @doc """
  Returns the resource's Ash attributes as a `%{name => attribute_struct}` map.

  Used by builders that need O(1) attribute lookup by name (FieldBuilder,
  ColumnBuilder).
  """
  @spec get_resource_attributes(module()) :: map()
  def get_resource_attributes(resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Map.new(&{&1.name, &1})
  end

  @doc """
  Returns `true` when the user has no tenant — i.e. is a master user.

  Canonical default for `master_user?/1` across the framework. The tenant
  attribute is currently `:site_id`.
  """
  @spec master_user?(map() | struct() | nil) :: boolean()
  def master_user?(%{site_id: nil}), do: true
  def master_user?(_), do: false

  @doc """
  Extracts the tenant value from a user map/struct (currently `:site_id`).

  Returns `nil` for nil users or users without the tenant attribute.
  """
  @spec user_tenant(map() | struct() | nil) :: any()
  def user_tenant(%{site_id: site_id}), do: site_id
  def user_tenant(_), do: nil

  @doc """
  Merges form-state relation field values into a params map.

  For each relation field with a value in `state.field_values`, places the
  value at the string-keyed slot in `params`. The sentinel `"__nil__"` is
  rewritten to a real `nil` so AshPhoenix can clear the relation. Empty
  string and `nil` values are ignored.

  Used by validation/submit handlers to ensure relation selections survive
  param re-merging.
  """
  @spec merge_relation_field_values(map(), map()) :: map()
  def merge_relation_field_values(params, state) do
    state.static.fields
    |> Enum.filter(&(&1.type == :relation))
    |> Enum.reduce(params, fn field, acc ->
      case Map.get(state.field_values, field.name) do
        "__nil__" -> Map.put(acc, to_string(field.name), nil)
        v when v not in [nil, ""] -> Map.put(acc, to_string(field.name), v)
        _ -> acc
      end
    end)
  end

  @doc """
  Fetch a key from a possibly-nil map, returning `default` when the key is
  missing or the value is nil.

  Used by the `Resource.Info.{Form,Table}` and `Domain.Info.{Form,Table}`
  introspection modules to absorb the repeating
  `case map do %{key: v} -> v; _ -> default end` shape.
  """
  @spec map_get(map() | nil, atom(), term()) :: term()
  def map_get(nil, _key, default), do: default

  def map_get(map, key, default) do
    case map do
      %{^key => value} when not is_nil(value) -> value
      _ -> default
    end
  end

  @doc """
  Unwrap a preload entry to its source atom. Preloads can be plain atoms or
  `{source, alias}` tuples — this returns the atom either way.
  """
  @spec extract_preload_source(atom() | {atom(), atom()}) :: atom()
  def extract_preload_source({source, _alias}), do: source
  def extract_preload_source(source) when is_atom(source), do: source

  @doc """
  Look up the Ash domain for a resource.
  """
  @spec get_domain(module()) :: {:ok, module()} | :error
  def get_domain(resource) do
    case Ash.Resource.Info.domain(resource) do
      nil -> :error
      domain -> {:ok, domain}
    end
  end

  @doc """
  Fetch the domain-side defaults map for a given section (`:form` or `:table`).
  Returns `%{}` when the resource has no domain or the domain has no
  `mishka_gervaz` block.
  """
  @spec get_domain_defaults(module(), atom()) :: map()
  def get_domain_defaults(resource, section) do
    with {:ok, domain} <- get_domain(resource),
         config when not is_nil(config) <-
           Spark.Dsl.Extension.get_persisted(domain, :mishka_gervaz_domain_config) do
      Map.get(config, section, %{})
    else
      _ -> %{}
    end
  end

  @doc """
  Unwraps a Spark singleton sub-entity wrapper into the entity itself.

  Spark stores DSL singleton entities under `key` as a single-element
  list during parse. After the parent entity's `transform/1` runs, the
  list is collapsed to the entity struct (or `nil` if absent). Used by
  every entity that owns one or more singleton sub-entities (e.g. `:ui`,
  `:preload`, plus `submit`'s `:create` / `:update` / `:cancel`).

  Idempotent: if the value is already a struct (transform already ran)
  or absent, the map is returned unchanged.
  """
  @spec extract_singleton_entity(map(), atom()) :: map()
  def extract_singleton_entity(map, key) do
    do_extract_singleton(Map.get(map, key), map, key)
  end

  defp do_extract_singleton([value | _], map, key), do: Map.put(map, key, value)
  defp do_extract_singleton([], map, key), do: Map.put(map, key, nil)
  defp do_extract_singleton(value, map, _key) when is_struct(value), do: map
  defp do_extract_singleton(_value, map, _key), do: map

  @doc """
  Drops nil values from a map and returns `nil` if the result is empty,
  otherwise returns the cleaned map.

  Used by transformers that build optional sub-config blocks where
  "no overrides set" should compile down to `nil` rather than an empty
  map. Idempotent on `nil` input.
  """
  @spec compact_to_nil(map() | nil) :: map() | nil
  def compact_to_nil(nil), do: nil

  def compact_to_nil(map) when is_map(map) do
    cleaned = Map.reject(map, fn {_, v} -> is_nil(v) end)
    if cleaned == %{}, do: nil, else: cleaned
  end

  @doc """
  Normalizes an Ash primary-key type to one of `:uuid`, `:uuid_v7`,
  `:integer`, or `:string`. Falls back to `:uuid` for anything else,
  matching the conservative default Phoenix uses for `<input>` shapes.

  Recognises both the bare atom forms (`:uuid`, `:integer`, `:string`)
  and the `Ash.Type.*` modules. Future `Ash.Type.UUIDv7` / `UUID7` /
  `UUID` / `Integer` modules are matched by name string so a Spark
  release that adds new vendor variants (`Ash.Type.UUIDv7Foo`) still
  routes correctly.
  """
  @spec normalize_id_type(any()) :: :uuid | :uuid_v7 | :integer | :string
  def normalize_id_type(type) when is_atom(type) do
    type_string = Atom.to_string(type)

    cond do
      type == :uuid or type == Ash.Type.UUID -> :uuid
      type == :integer or type == Ash.Type.Integer -> :integer
      type == :string or type == Ash.Type.String -> :string
      String.contains?(type_string, "UUIDv7") -> :uuid_v7
      String.contains?(type_string, "UUID7") -> :uuid_v7
      String.contains?(type_string, "UUID") -> :uuid
      String.contains?(type_string, "Integer") -> :integer
      true -> :uuid
    end
  end

  def normalize_id_type(_), do: :uuid

  @doc """
  Returns the normalized type of `resource`'s primary key as one of
  `:uuid`, `:uuid_v7`, `:integer`, or `:string`. Defaults to `:uuid`
  when introspection fails or the resource has no primary key.
  """
  @spec primary_key_type(module()) :: :uuid | :uuid_v7 | :integer | :string
  def primary_key_type(resource) do
    case Ash.Resource.Info.primary_key(resource) do
      [pk_field | _] ->
        case Ash.Resource.Info.attribute(resource, pk_field) do
          %{type: type} -> normalize_id_type(type)
          _ -> :uuid
        end

      _ ->
        :uuid
    end
  rescue
    _ -> :uuid
  end

  @doc """
  Resolves the destination resource of a relation field/filter.

  Accepts any map with `:name` / `:source` / `:resource` keys (the
  shape Form.Field and Table.Filter both have):

    * If `:resource` is set on the entity, returns it directly.
    * Otherwise looks up `parent_resource`'s Ash relationships for the
      one whose `source_attribute` matches `entity.source || entity.name`
      and returns its `:destination`.
    * Returns `nil` when no match is found, when `parent_resource` is
      `nil`, or on any introspection failure.
  """
  @spec relation_target_resource(map(), module() | nil) :: module() | nil
  def relation_target_resource(%{resource: resource}, _parent) when not is_nil(resource),
    do: resource

  def relation_target_resource(%{name: name, source: source}, parent) when not is_nil(parent) do
    field_name = source || name

    case parent
         |> Ash.Resource.Info.relationships()
         |> Enum.find(&(&1.source_attribute == field_name)) do
      %{destination: dest} -> dest
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def relation_target_resource(_, _), do: nil

  @doc """
  Returns the normalized id-type for a `:relation` entity, defaulting
  to `:uuid` when the related resource cannot be found.

  Combines `relation_target_resource/2` and `primary_key_type/1`. For
  non-relation entities returns `nil`.
  """
  @spec relation_id_type(map(), module() | nil) ::
          :uuid | :uuid_v7 | :integer | :string | nil
  def relation_id_type(%{type: :relation} = entity, parent) do
    case relation_target_resource(entity, parent) do
      nil -> :uuid
      resource -> primary_key_type(resource)
    end
  end

  def relation_id_type(_entity, _parent), do: nil
end

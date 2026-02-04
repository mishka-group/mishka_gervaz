defmodule MishkaGervaz.Table.Behaviours.TypeRegistry do
  @moduledoc """
  Behaviour for type registry modules.

  Ensures consistent API across column, filter, and action type registries.
  Each registry maps atom names to module implementations.

  ## Usage

  ### Simple format (for filters, actions)

      defmodule MyApp.Table.Types.Filter do
        use MishkaGervaz.Table.Behaviours.TypeRegistry,
          builtin: %{
            text: MyApp.Table.Types.Filter.Text,
            select: MyApp.Table.Types.Filter.Select
          },
          default: MyApp.Table.Types.Filter.Text
      end

  ### Tuple format with Ash type inference (for columns)

      defmodule MyApp.Table.Types.Column do
        use MishkaGervaz.Table.Behaviours.TypeRegistry,
          builtin: %{
            text: {MyApp.Table.Types.Column.Text, []},
            boolean: {MyApp.Table.Types.Column.Boolean, [Ash.Type.Boolean]},
            number: {MyApp.Table.Types.Column.Number, [Ash.Type.Integer, Ash.Type.Float]}
          },
          default: MyApp.Table.Types.Column.Text
      end

  When using tuple format `{Module, [AshTypes]}`, the macro automatically generates
  `infer_from_ash_type/1` that maps Ash types to the corresponding module.

  ## Provided Functions

  When you `use` this behaviour, you get:

  - `get/1` - Get module by atom name (returns module or nil)
  - `builtin_types/0` - List all registered type names
  - `builtin?/1` - Check if type name is registered
  - `default/0` - Get the default type module
  - `get_or_passthrough/1` - Get module, or return type as-is for custom modules
  - `infer_from_ash_type/1` - (tuple format only) Infer module from Ash attribute type

  ## Optional Callbacks

  - `resolve_type/1` - Resolve type from config map (single context)
  - `resolve_type/2` - Resolve type from config map with extra context
  """

  @doc """
  Get the module for a built-in type.

  Returns the module if found, nil otherwise.
  """
  @callback get(type :: atom()) :: module() | nil

  @doc """
  List all built-in type names.
  """
  @callback builtin_types() :: [atom()]

  @doc """
  Check if a type name is a built-in type.
  """
  @callback builtin?(type :: atom()) :: boolean()

  @doc """
  Resolve type module from configuration.

  Used when type needs to be determined from a config map
  (e.g., filter config with `:type` key).
  """
  @callback resolve_type(config :: map()) :: module()

  @doc """
  Resolve type module from configuration with additional context.

  Used when type resolution needs extra context
  (e.g., column config + resource attributes).
  """
  @callback resolve_type(config :: map(), context :: map()) :: module()

  @optional_callbacks [resolve_type: 1, resolve_type: 2]

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour MishkaGervaz.Table.Behaviours.TypeRegistry

      {builtin_modules, ash_type_mappings} =
        MishkaGervaz.Table.Behaviours.TypeRegistry.normalize_builtin(
          Keyword.get(opts, :builtin, %{})
        )

      @__builtin_types__ builtin_modules
      @__default_type__ Keyword.get(opts, :default)
      @__ash_type_mappings__ ash_type_mappings

      @impl true
      @doc """
      Get module by type name.

      Returns the module for built-in types, or the type itself
      if it's already a module (for custom types).
      """
      @spec get(atom()) :: module() | nil
      def get(type) when is_atom(type) do
        Map.get(@__builtin_types__, type)
      end

      @impl true
      @doc """
      List all built-in type names.
      """
      @spec builtin_types() :: [atom()]
      def builtin_types, do: Map.keys(@__builtin_types__)

      @impl true
      @doc """
      Check if type name is registered.
      """
      @spec builtin?(atom()) :: boolean()
      def builtin?(type) when is_atom(type) do
        Map.has_key?(@__builtin_types__, type)
      end

      @doc """
      Get the default type module.
      """
      @spec default() :: module() | nil
      def default, do: @__default_type__

      @doc """
      Get module, falling back to type itself for custom modules.

      Unlike `get/1` which returns nil for unknown types,
      this returns the type as-is (assuming it's a custom module).
      """
      @spec get_or_passthrough(atom()) :: module()
      def get_or_passthrough(type) when is_atom(type) do
        Map.get(@__builtin_types__, type, type)
      end

      defoverridable get: 1, builtin_types: 0, builtin?: 1

      if @__ash_type_mappings__ != [] do
        @doc """
        Infer column type module from Ash attribute type.

        Maps Ash types to appropriate column type modules for rendering.
        Returns default type when attribute is nil or type is unknown.

        Auto-generated from builtin type registry mappings.
        """
        @spec infer_from_ash_type(map() | nil) :: module()
        def infer_from_ash_type(nil), do: default()

        def infer_from_ash_type(%{type: type}) do
          MishkaGervaz.Table.Behaviours.TypeRegistry.lookup_ash_type(
            type,
            @__ash_type_mappings__,
            @__default_type__
          )
        end
      end
    end
  end

  @doc false
  @spec normalize_builtin(map()) :: {map(), list()}
  def normalize_builtin(builtin_raw) do
    Enum.reduce(builtin_raw, {%{}, []}, fn
      {name, {module, ash_types}}, {modules, mappings} when is_list(ash_types) ->
        new_mappings = Enum.map(ash_types, fn ash_type -> {ash_type, module} end)
        {Map.put(modules, name, module), mappings ++ new_mappings}

      {name, module}, {modules, mappings} ->
        {Map.put(modules, name, module), mappings}
    end)
  end

  @doc false
  @spec lookup_ash_type(atom() | {:array, any()}, list(), module() | nil) :: module() | nil
  def lookup_ash_type({:array, _}, mappings, default_type) do
    Enum.find_value(mappings, default_type, fn
      {:__array__, module} -> module
      _ -> nil
    end)
  end

  def lookup_ash_type(type, mappings, default_type) do
    Enum.find_value(mappings, default_type, fn
      {^type, module} -> module
      _ -> nil
    end)
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.HookRunner do
  @moduledoc """
  Executes hooks during data loading.

  ## Overridable Functions

  - `run_hook/3` - Run a hook by name with arguments
  - `apply_hook_result/2` - Apply hook result to query

  ## User Override

      defmodule MyApp.Table.DataLoader.HookRunner do
        use MishkaGervaz.Table.Web.DataLoader.HookRunner

        def run_hook(hooks, hook_name, args) do
          # Add logging
          Logger.debug("Running hook: \#{hook_name}")
          result = super(hooks, hook_name, args)
          Logger.debug("Hook result: \#{inspect(result)}")
          result
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Table.Web.DataLoader.Builder

      @doc """
      Run a hook by name with the given arguments.
      Returns the hook result or nil if hook doesn't exist.
      """
      @spec run_hook(map() | nil, atom(), list()) :: {:cont, any()} | {:halt, any()} | nil
      def run_hook(hooks, hook_name, args) when is_map(hooks) do
        case Map.get(hooks, hook_name) do
          func when is_function(func) ->
            apply(func, args)

          _ ->
            nil
        end
      end

      def run_hook(_, _, _), do: nil

      @doc """
      Apply hook result to query.
      Returns modified query or original if hook halts.
      """
      @spec apply_hook_result(any(), Ash.Query.t()) :: Ash.Query.t()
      def apply_hook_result({:cont, modified_query}, _query), do: modified_query
      def apply_hook_result({:halt, _}, query), do: query
      def apply_hook_result(_, query), do: query

      defoverridable run_hook: 3,
                     apply_hook_result: 2
    end
  end
end

defmodule MishkaGervaz.Table.Web.DataLoader.HookRunner.Default do
  @moduledoc false
  use MishkaGervaz.Table.Web.DataLoader.HookRunner
end

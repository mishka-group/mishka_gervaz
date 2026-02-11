defmodule MishkaGervaz.Form.Web.Events.HookRunner do
  @moduledoc """
  Executes lifecycle hooks during form events.

  ## Overridable Functions

  - `run_hook/3` - Run a hook by name with arguments
  - `apply_hook_result/2` - Apply hook result to target

  ## User Override

      defmodule MyApp.Form.Events.HookRunner do
        use MishkaGervaz.Form.Web.Events.HookRunner

        def run_hook(hooks, hook_name, args) do
          Logger.debug("Running form event hook: \#{hook_name}")
          super(hooks, hook_name, args)
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      @doc """
      Run a hook by name with the given arguments.
      Returns the hook result or nil if hook doesn't exist.
      """
      @spec run_hook(map() | nil, atom(), list()) :: any()
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
      Apply hook result to the target value.
      Returns modified value or original if hook halts or returns nil.
      """
      @spec apply_hook_result(any(), any()) :: any()
      def apply_hook_result({:cont, modified}, _original), do: modified
      def apply_hook_result({:halt, _}, original), do: original
      def apply_hook_result(_, original), do: original

      defoverridable run_hook: 3,
                     apply_hook_result: 2
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.HookRunner.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.HookRunner
end

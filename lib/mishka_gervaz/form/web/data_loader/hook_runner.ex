defmodule MishkaGervaz.Form.Web.DataLoader.HookRunner do
  @moduledoc """
  Executes hooks during form data loading.

  ## Overridable Functions

  - `run_hook/3` - Run a hook by name with arguments
  - `apply_hook_result/2` - Apply hook result to form/params

  ## User Override

      defmodule MyApp.Form.DataLoader.HookRunner do
        use MishkaGervaz.Form.Web.DataLoader.HookRunner

        def run_hook(hooks, hook_name, args) do
          Logger.debug("Running form hook: \#{hook_name}")
          super(hooks, hook_name, args)
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.DataLoader.Builder

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

defmodule MishkaGervaz.Form.Web.DataLoader.HookRunner.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.DataLoader.HookRunner
end

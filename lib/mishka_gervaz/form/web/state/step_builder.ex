defmodule MishkaGervaz.Form.Web.State.StepBuilder do
  @moduledoc """
  Builds wizard/tabs step configuration from DSL.

  Steps define the multi-step form flow. Each step references groups,
  has optional validation actions, and lifecycle callbacks.

  ## Overridable Functions

  - `build/2` - Build steps from config and resource
  - `initial_step/1` - Determine the initial step
  - `initial_step_states/1` - Build initial step states map
  - `step_valid?/2` - Check if a step is valid/complete

  ## User Override

      defmodule MyApp.Form.StepBuilder do
        use MishkaGervaz.Form.Web.State.StepBuilder

        def initial_step(steps) do
          # Always start at the second step
          case steps do
            [_, second | _] -> second.name
            _ -> super(steps)
          end
        end
      end
  """

  alias MishkaGervaz.Resource.Info.Form, as: Info

  @doc false
  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.State.Builder

      alias MishkaGervaz.Resource.Info.Form, as: Info

      import MishkaGervaz.Helpers, only: [get_ui_label: 1]

      @doc """
      Builds steps from config and resource.

      Returns a list of step config maps with resolved labels.
      """
      @spec build(map(), module()) :: list(map())
      def build(config, resource) when is_map(config) do
        Info.steps(resource)
        |> Enum.map(fn step ->
          label = get_ui_label(step)
          Map.put(step, :resolved_label, label)
        end)
      end

      @spec build(term(), term()) :: list()
      def build(_, _), do: []

      @doc """
      Determines the initial step name.

      Returns the name of the first step, or nil if no steps.
      """
      @spec initial_step(list(map())) :: atom() | nil
      def initial_step([first | _]), do: first.name
      def initial_step([]), do: nil

      @doc """
      Builds the initial step states map.

      The first step starts as `:active`, all others as `:pending`.
      """
      @spec initial_step_states(list(map())) :: %{atom() => :pending | :active | :completed | :error}
      def initial_step_states([]), do: %{}

      def initial_step_states([first | rest]) do
        rest_states = Map.new(rest, &{&1.name, :pending})
        Map.put(rest_states, first.name, :active)
      end

      @doc """
      Checks if a step is valid/complete.

      Override this to add custom validation per step.
      """
      @spec step_valid?(map(), map()) :: boolean()
      def step_valid?(_step, _form_state), do: true

      defoverridable build: 2, initial_step: 1, initial_step_states: 1, step_valid?: 2
    end
  end
end

defmodule MishkaGervaz.Form.Web.State.StepBuilder.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.State.StepBuilder
end

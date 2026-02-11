defmodule MishkaGervaz.Form.Web.Events.StepHandler do
  @moduledoc """
  Handles wizard step navigation events.

  ## Overridable Functions

  - `can_advance?/2` - Check if user can move to next step
  - `advance/2` - Move to the next step
  - `go_back/1` - Move to the previous step
  - `goto_step/2` - Jump to a specific step (tabs mode)

  ## User Override

      defmodule MyApp.Form.StepHandler do
        use MishkaGervaz.Form.Web.Events.StepHandler

        def can_advance?(state, current_step) do
          # Custom step validation
          super(state, current_step)
        end
      end
  """

  alias MishkaGervaz.Form.Web.State

  defmacro __using__(_opts) do
    quote do
      use MishkaGervaz.Form.Web.Events.Builder

      alias MishkaGervaz.Form.Web.State

      @doc """
      Check if the user can advance past the current step.

      Override for custom per-step validation.
      """
      @spec can_advance?(State.t(), atom()) :: boolean()
      def can_advance?(_state, _current_step), do: true

      @doc """
      Move to the next step in the wizard.

      Marks the current step as completed and activates the next step.
      """
      @spec advance(State.t(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
      def advance(state, socket) do
        steps = state.static.steps
        current = state.current_step

        case find_next_step(steps, current) do
          nil ->
            socket

          next_step ->
            if can_advance?(state, current) do
              step_states =
                state.step_states
                |> Map.put(current, :completed)
                |> Map.put(next_step, :active)

              history = [next_step | state.wizard_history] |> Enum.uniq()

              state =
                State.update(state,
                  current_step: next_step,
                  step_states: step_states,
                  wizard_history: history
                )

              Phoenix.Component.assign(socket, :form_state, state)
            else
              step_states = Map.put(state.step_states, current, :error)
              state = State.update(state, step_states: step_states)
              Phoenix.Component.assign(socket, :form_state, state)
            end
        end
      end

      @doc """
      Move to the previous step in the wizard.

      Uses wizard_history to determine the previous step.
      """
      @spec go_back(State.t(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
      def go_back(state, socket) do
        steps = state.static.steps
        current = state.current_step

        case find_prev_step(steps, current) do
          nil ->
            socket

          prev_step ->
            step_states =
              state.step_states
              |> Map.put(current, :pending)
              |> Map.put(prev_step, :active)

            state =
              State.update(state,
                current_step: prev_step,
                step_states: step_states
              )

            Phoenix.Component.assign(socket, :form_state, state)
        end
      end

      @doc """
      Jump to a specific step (for tabs/free navigation mode).

      Only allowed when layout_navigation is :free, or the target step
      has been visited before.
      """
      @spec goto_step(State.t(), atom(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def goto_step(state, target_step, socket) do
        can_jump? =
          state.static.layout_navigation == :free or
            target_step in state.wizard_history

        if can_jump? and step_exists?(state, target_step) do
          step_states =
            state.step_states
            |> Map.put(state.current_step, Map.get(state.step_states, state.current_step, :pending))
            |> Map.put(target_step, :active)

          history = [target_step | state.wizard_history] |> Enum.uniq()

          state =
            State.update(state,
              current_step: target_step,
              step_states: step_states,
              wizard_history: history
            )

          Phoenix.Component.assign(socket, :form_state, state)
        else
          socket
        end
      end

      @spec find_next_step(list(map()), atom()) :: atom() | nil
      defp find_next_step(steps, current) do
        step_names = Enum.map(steps, & &1.name)
        current_idx = Enum.find_index(step_names, &(&1 == current))

        case current_idx do
          nil -> nil
          idx -> Enum.at(step_names, idx + 1)
        end
      end

      @spec find_prev_step(list(map()), atom()) :: atom() | nil
      defp find_prev_step(steps, current) do
        step_names = Enum.map(steps, & &1.name)
        current_idx = Enum.find_index(step_names, &(&1 == current))

        case current_idx do
          nil -> nil
          0 -> nil
          idx -> Enum.at(step_names, idx - 1)
        end
      end

      @spec step_exists?(State.t(), atom()) :: boolean()
      defp step_exists?(state, step_name) do
        Enum.any?(state.static.steps, &(&1.name == step_name))
      end

      defoverridable can_advance?: 2,
                     advance: 2,
                     go_back: 2,
                     goto_step: 3
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.StepHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.StepHandler
end

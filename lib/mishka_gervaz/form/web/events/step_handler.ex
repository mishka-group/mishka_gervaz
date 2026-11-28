defmodule MishkaGervaz.Form.Web.Events.StepHandler do
  @moduledoc """
  Handles wizard step navigation events.

  ## How a wizard moves

  The template draws every step and shows the current one; Next is the form's submit button, so
  Enter in a field presses it too. `MishkaGervaz.Form.Web.Events` handles the form's submit by step:

    * on any step but the last, it validates what the form holds and calls `advance/2`, which
      moves to the next step when `can_advance?/2` allows it. A step it refuses is marked `:error`
      and shows the errors of its own fields (`step_errors/2`), never another step's, and they
      follow what is typed until the step moves on. Nothing is saved, unless the step says
      `save true` (`step_saves?/1`): then a step `can_advance?/2` allows is saved as the last step
      is, and a save that succeeds opens the saved record for editing on the next step (see
      `MishkaGervaz.Form.Entities.Step`, "A step that saves").
    * on the last step, it saves. A save that fails on a field of another step calls
      `goto_errors/2`, which moves the form to the first step holding an error, marks every step
      holding one `:error`, and sends the parent LiveView `{:put_flash, :error, message}`, the
      message naming the step to check.

  Back (`prev_step`) moves to the previous step and counts it as visited. Every step stays in the
  form, so nothing typed on either is lost.

  A tab opens the steps `open_steps/1` names: every step on free tabs and on a saved record, the
  visited ones while a record is made.

  ## Overridable Functions

  - `can_advance?/2` - Check if user can move to next step
  - `advance/2` - Move to the next step
  - `go_back/2` - Move to the previous step
  - `goto_step/3` - Jump to a specific step (tabs mode)
  - `goto_errors/2` - Move a form whose save failed to the step holding the error

  ## User Override

      defmodule MyApp.Form.StepHandler do
        use MishkaGervaz.Form.Web.Events.StepHandler

        def can_advance?(state, current_step) do
          # Custom step validation
          super(state, current_step)
        end
      end

  Top-level helpers `find_next_step/2`, `find_prev_step/2`, `step_exists?/2`, `step_fields/2` and
  `step_errors/2` are public so user overrides can reuse them.

  See `MishkaGervaz.Form.Web.Events`,
  `MishkaGervaz.Form.Web.State` (for `:current_step`, `:step_states`,
  `:wizard_history`), and the sibling sub-handlers.
  """

  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers, only: [accessible?: 2, translate_text: 1]

  alias MishkaGervaz.Errors
  alias MishkaGervaz.Form.Web.Events.SubmitHandler
  alias MishkaGervaz.Form.Web.State

  @doc false
  @spec find_next_step(list(map()), atom()) :: atom() | nil
  def find_next_step(steps, current) do
    step_names = Enum.map(steps, & &1.name)
    current_idx = Enum.find_index(step_names, &(&1 == current))

    case current_idx do
      nil -> nil
      idx -> Enum.at(step_names, idx + 1)
    end
  end

  @doc false
  @spec find_prev_step(list(map()), atom()) :: atom() | nil
  def find_prev_step(steps, current) do
    step_names = Enum.map(steps, & &1.name)
    current_idx = Enum.find_index(step_names, &(&1 == current))

    case current_idx do
      nil -> nil
      0 -> nil
      idx -> Enum.at(step_names, idx - 1)
    end
  end

  @doc false
  @spec step_exists?(map(), atom()) :: boolean()
  def step_exists?(state, step_name) do
    Enum.any?(state.static.steps, &(&1.name == step_name))
  end

  @doc """
  The names of the fields step `step_name` draws for the current reader, in its groups' order: the
  fields of its groups that are `visible`, not `restricted` for the reader, and shown in the form's
  mode.
  """
  @spec step_fields(map(), atom()) :: [atom()]
  def step_fields(%{static: %{groups: groups, steps: steps, fields: fields}} = state, step_name) do
    names =
      groups
      |> State.Helpers.groups_for_step(steps, step_name)
      |> Enum.filter(&accessible?(&1, state))
      |> Enum.flat_map(&Map.get(&1, :fields, []))

    shown =
      for field <- fields,
          field.name in names,
          accessible?(field, state),
          Map.get(field, :show_on) in [nil, state.mode],
          into: MapSet.new(),
          do: field.name

    Enum.filter(names, &MapSet.member?(shown, &1))
  end

  def step_fields(_state, _step_name), do: []

  @doc """
  The errors the validated form (`state.form`) holds on the fields of step `step_name`
  (`step_fields/2`), by field, each message translated. Empty when the form holds none there.
  """
  @spec step_errors(map(), atom()) :: %{atom() => [String.t()]}
  def step_errors(%{form: %Phoenix.HTML.Form{} = form} = state, step_name) do
    form
    |> SubmitHandler.format_form_errors()
    |> Map.take(step_fields(state, step_name))
  end

  def step_errors(_state, _step_name), do: %{}

  @doc false
  @spec moved(map(), atom(), atom()) :: map()
  def moved(state, from, to) do
    State.update(state,
      current_step: to,
      step_states: state.step_states |> Map.put(from, :completed) |> Map.put(to, :active),
      wizard_history: Enum.uniq([to | state.wizard_history])
    )
  end

  @doc """
  Whether Next on the form's current step saves: the step says `save true`, it is not the last
  step, and the form moves step by step (a wizard, or tabs whose steps open in order).
  """
  @spec step_saves?(map()) :: boolean()
  def step_saves?(%{static: %{steps: [_ | _] = steps} = static, current_step: current}) do
    stepwise?(static) and List.last(steps).name != current and
      Enum.any?(steps, &(&1.name == current and Map.get(&1, :save) == true))
  end

  def step_saves?(_state), do: false

  @doc """
  The name of the form's step that `step` names, an atom or its string, as a page may take it from
  a URL; `nil` when the form has no such step.
  """
  @spec step_name(map(), atom() | String.t() | nil) :: atom() | nil
  def step_name(%{static: %{steps: steps}}, step) when is_atom(step) and not is_nil(step),
    do: Enum.find_value(steps, &(&1.name == step && step))

  def step_name(%{static: %{steps: steps}}, step) when is_binary(step),
    do: Enum.find_value(steps, &(Atom.to_string(&1.name) == step && &1.name))

  def step_name(_state, _step), do: nil

  @doc """
  The form put on step `step` without checking a step on the way: the step `:active`. A wizard,
  and a tabs form whose steps open in order, count the steps before it as done, `:completed` and
  visited, so Back and their tabs reach them; on free tabs every other step is `:pending`.
  """
  @spec opened(map(), atom()) :: map()
  def opened(%{static: %{steps: steps} = static} = state, step) do
    names = Enum.map(steps, & &1.name)
    done = if stepwise?(static), do: Enum.take_while(names, &(&1 != step)), else: []

    State.update(state,
      current_step: step,
      step_states: Map.new(names, &{&1, opened_status(&1, step, done)}),
      wizard_history: Enum.uniq([step | Enum.reverse(done)] ++ (state.wizard_history || []))
    )
  end

  @doc """
  The names of the steps the reader may open from a tab: every step on free tabs and on a saved
  record (`mode: :update`); otherwise the steps already visited, with the step shown always among
  them, so a step is never drawn shown and closed at once.
  """
  @spec open_steps(map()) :: [atom()]
  def open_steps(%{static: %{layout_navigation: :free, steps: steps}}),
    do: Enum.map(steps, & &1.name)

  def open_steps(%{mode: :update, static: %{steps: steps}}), do: Enum.map(steps, & &1.name)

  def open_steps(%{current_step: current, wizard_history: history}),
    do: Enum.uniq(List.wrap(current) ++ (history || []))

  defp opened_status(step, step, _done), do: :active
  defp opened_status(name, _step, done), do: (name in done && :completed) || :pending

  defp stepwise?(%{layout_mode: :wizard}), do: true
  defp stepwise?(%{layout_mode: :tabs, layout_navigation: navigation}), do: navigation != :free
  defp stepwise?(_static), do: false

  @doc false
  @spec refused(map(), atom()) :: map()
  def refused(state, step) do
    State.update(state,
      step_states: Map.put(state.step_states, step, :error),
      errors: Map.merge(state.errors || %{}, step_errors(state, step))
    )
  end

  @doc false
  @spec to_errors(map()) :: {map(), String.t() | nil} | nil
  def to_errors(%{errors: errors, static: %{steps: steps}} = state) when is_map(errors) do
    failed =
      for {step, number} <- Enum.with_index(steps, 1),
          field = Enum.find(step_fields(state, step.name), &(Map.get(errors, &1, []) != [])),
          do: {number, step, field}

    case failed do
      [] ->
        nil

      [{_number, first, _field} = shown | _] ->
        step_states =
          Enum.reduce(failed, state.step_states, &Map.put(&2, elem(&1, 1).name, :error))

        flash = if first.name != state.current_step, do: flash_message(state, shown)

        {State.update(state,
           current_step: first.name,
           step_states: step_states,
           wizard_history: Enum.uniq([first.name | state.wizard_history])
         ), flash}
    end
  end

  def to_errors(_state), do: nil

  defp flash_message(state, {number, step, field}) do
    message =
      state.errors
      |> Map.fetch!(field)
      |> List.first()
      |> Errors.field_message([], field, state.static.resource)

    dgettext("mishka_gervaz", "%{message} Check it on step %{number}, %{step}.",
      message: message,
      number: number,
      step: translate_text(Map.get(step, :resolved_label) || to_string(step.name))
    )
  end

  defmacro __using__(_opts) do
    quote do
      alias MishkaGervaz.Form.Web.Events.StepHandler
      alias MishkaGervaz.Form.Web.State

      import MishkaGervaz.Form.Web.Events.StepHandler,
        only: [
          find_next_step: 2,
          find_prev_step: 2,
          step_exists?: 2,
          step_fields: 2,
          step_errors: 2
        ]

      @doc """
      Whether the form may move past `current_step`: no field the step draws holds an error in the
      validated form (`step_errors/2`).

      Override for custom per-step validation.
      """
      @spec can_advance?(State.t(), atom()) :: boolean()
      def can_advance?(state, current_step), do: step_errors(state, current_step) == %{}

      @doc """
      Move to the next step in the wizard.

      Marks the current step as completed and activates the next step. A step `can_advance?/2`
      refuses stays, marked `:error`, with the errors of its fields shown.
      """
      @spec advance(State.t(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
      def advance(state, socket) do
        steps = state.static.steps
        current = state.current_step

        case find_next_step(steps, current) do
          nil ->
            socket

          next_step ->
            state =
              if apply(__MODULE__, :can_advance?, [state, current]),
                do: StepHandler.moved(state, current, next_step),
                else: StepHandler.refused(state, current)

            Phoenix.Component.assign(socket, :form_state, state)
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
                step_states: step_states,
                wizard_history: Enum.uniq([prev_step | state.wizard_history || []])
              )

            Phoenix.Component.assign(socket, :form_state, state)
        end
      end

      @doc """
      Jump to a specific step (for tabs/free navigation mode).

      Only allowed to a step `MishkaGervaz.Form.Web.Events.StepHandler.open_steps/1` names: any
      step on free tabs or a saved record, otherwise a step visited before.
      """
      @spec goto_step(State.t(), atom(), Phoenix.LiveView.Socket.t()) ::
              Phoenix.LiveView.Socket.t()
      def goto_step(state, target_step, socket) do
        can_jump? = target_step in StepHandler.open_steps(state)

        if can_jump? and step_exists?(state, target_step) do
          step_states =
            state.step_states
            |> Map.put(
              state.current_step,
              Map.get(state.step_states, state.current_step, :pending)
            )
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

      @doc """
      Moves a form whose save failed to the first step holding a field with an error
      (`state.errors`), and marks every step holding one `:error`.

      When that step is not the one the save was sent from, it also sends the parent LiveView
      `{:put_flash, :error, message}`, the message being the field's first error followed by the
      step to check, such as "Nothing answered at this address. Check it on step 1, Where from.".
      A form whose errors are on no field (`state.form_errors`) stays where it is: those show
      above the submit row.
      """
      @spec goto_errors(State.t(), Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
      def goto_errors(state, socket) do
        case StepHandler.to_errors(state) do
          nil ->
            socket

          {state, flash} ->
            if flash, do: send(self(), {:put_flash, :error, flash})
            Phoenix.Component.assign(socket, :form_state, state)
        end
      end

      defoverridable can_advance?: 2, advance: 2, go_back: 2, goto_step: 3, goto_errors: 2
    end
  end
end

defmodule MishkaGervaz.Form.Web.Events.StepHandler.Default do
  @moduledoc false
  use MishkaGervaz.Form.Web.Events.StepHandler
end

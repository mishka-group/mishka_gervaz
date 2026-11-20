defmodule MishkaGervaz.Question do
  @moduledoc """
  The question window a row action, a bulk action or a form's submit button asks before it acts.

  A `confirm` given as a string asks the browser's own question, through `data-confirm`. A
  `confirm` given as a keyword list asks it in the UI adapter's `question/1` window instead, drawn
  by the server, with a title, a sentence, a tone and its own button labels, and, with `answer`, a
  field the reader types a word into ("type the name to confirm") before the button answers:

      action :delete, type: :destroy,
        confirm: [
          title: fn record -> "Delete \#{record.name}?" end,
          body: "Its files and its sales history are deleted with it.",
          tone: :danger,
          answer: fn record -> record.name end,
          confirm_label: "Delete product"
        ]

  Each value but `tone` is a string, translated, or a function of one argument: the row of a row
  action, the number of rows of a bulk action (`nil` when the table cannot tell), and the record
  a form edits (`nil` on create). In a bulk action's strings, `{count}` becomes that number.

  The press sends its component `"ask"` instead of its own event, carrying the event's values; the
  component keeps the question with the event and its values (`pending/3`), and draws `window/1`.
  The window's typing sends `"question_typed"`, its button `"question_confirm"` and its Cancel,
  backdrop and Escape `"question_cancel"`. A confirm whose answer matches (`answered?/1`) runs the
  event it kept, with its values; one that does not stays open and says so (`refuse/1`). Nothing in
  it is JavaScript: the window is drawn and taken away by the server.
  """

  use Phoenix.Component
  use MishkaGervaz.Messages

  import MishkaGervaz.Helpers, only: [dynamic_component: 1, translate_text: 1]

  @tones [:danger, :warn, :info]

  @typedoc "A question as the component keeps it while its window is open."
  @type t :: %{
          title: String.t() | nil,
          body: String.t() | nil,
          tone: :danger | :warn | :info,
          answer: String.t() | nil,
          answer_label: String.t() | nil,
          confirm_label: String.t() | nil,
          cancel_label: String.t() | nil,
          typed: String.t(),
          error: String.t() | nil,
          event: String.t() | nil,
          params: map()
        }

  @doc """
  The keys of a question, as an option schema: `title`, `body`, `tone`, `answer`,
  `answer_label`, `confirm_label` and `cancel_label`. `arg` says in the docs what a function value
  is given.
  """
  @spec schema(String.t()) :: keyword()
  def schema(arg) do
    text = {:or, [:string, {:fun, 1}]}

    [
      title: [type: text, required: true, doc: "The question, such as \"Delete this product?\"."],
      body: [type: text, doc: "A sentence under it: what the action does and what is lost."],
      tone: [
        type: {:in, @tones},
        default: :danger,
        doc: "`:danger` (the default), `:warn` or `:info`: the colour of the window's button."
      ],
      answer: [
        type: text,
        doc: "A word the reader types before the button answers, such as the record's name."
      ],
      answer_label: [type: text, doc: "The label of the field the answer is typed into."],
      confirm_label: [type: text, doc: "The label of the button that answers."],
      cancel_label: [type: text, doc: "The label of the button that closes the window."]
    ]
    |> Enum.map(fn {key, opts} ->
      {key, Keyword.update!(opts, :doc, &"#{&1} A function is given #{arg}.")}
    end)
  end

  @doc """
  Whether a `confirm` asks in the question window: a keyword list or a map with a `:title`.
  A string or a function asks the browser's own question.

      iex> MishkaGervaz.Question.question?(title: "Delete?")
      true
      iex> MishkaGervaz.Question.question?("Delete?")
      false
  """
  @spec question?(term()) :: boolean()
  def question?([{key, _value} | _rest] = confirm) when is_atom(key),
    do: Keyword.has_key?(confirm, :title)

  def question?(%{title: _title}), do: true
  def question?(_confirm), do: false

  @doc """
  The question a `confirm` asks about `subject`, its strings translated and its functions given
  `subject`. With `count: n`, `{count}` in its strings becomes `n` (it stays when `n` is `nil`).
  `nil` when `confirm` is not a question (`question?/1`).
  """
  @spec build(term(), term(), keyword()) :: t() | nil
  def build(confirm, subject, opts \\ []) do
    if question?(confirm) do
      read = fn key -> confirm |> Access.get(key) |> resolve(subject, opts[:count]) end

      %{
        title: read.(:title),
        body: read.(:body),
        tone: tone(Access.get(confirm, :tone)),
        answer: read.(:answer),
        answer_label: read.(:answer_label),
        confirm_label: read.(:confirm_label),
        cancel_label: read.(:cancel_label),
        typed: "",
        error: nil,
        event: nil,
        params: %{}
      }
    end
  end

  defp tone(tone) when tone in @tones, do: tone
  defp tone(_tone), do: :danger

  defp resolve(value, subject, count) when is_function(value, 1),
    do: value |> apply([subject]) |> resolve(subject, count)

  defp resolve(value, _subject, count) when is_binary(value),
    do: value |> translate_text() |> put_count(count)

  defp resolve(nil, _subject, _count), do: nil
  defp resolve(value, _subject, _count), do: to_string(value)

  defp put_count(text, count) when is_integer(count),
    do: String.replace(text, "{count}", Integer.to_string(count))

  defp put_count(text, _count), do: text

  @doc """
  Puts an action's `confirm` on the assigns an `MishkaGervaz.Table.Behaviours.ActionType` builds
  for its button, after its `:phx_click` (an event name) and its `phx_value_*` values.

  A question turns the press into `"ask"`: the button's event moves to `:phx_value_ask`, beside
  `:phx_value_question` (the action's name) and `:phx_value_record` (the row's id), and its other
  values stay, so the table runs the very event with the very values once the question is
  answered. Any other `confirm` becomes `:data_confirm`, the browser's own question, or `default`
  when the action declares none.
  """
  @spec bind(map(), map(), map(), String.t() | nil) :: map()
  def bind(assigns, action, record, default \\ nil) do
    confirm = action[:confirm]

    if question?(confirm) do
      assigns
      |> assign(:phx_value_ask, assigns.phx_click)
      |> assign(:phx_click, "ask")
      |> assign(:phx_value_question, to_string(action[:name]))
      |> assign(:phx_value_record, record.id)
    else
      assign(
        assigns,
        :data_confirm,
        MishkaGervaz.Helpers.resolve_confirm(confirm, record) || default
      )
    end
  end

  @doc "Keeps with the question the event it runs on a confirm, and that event's values."
  @spec pending(t(), String.t(), map()) :: t()
  def pending(question, event, params), do: %{question | event: event, params: params}

  @doc "The question with what the reader has typed into its field, its refusal cleared."
  @spec put_typed(t(), term()) :: t()
  def put_typed(question, typed) when is_binary(typed), do: %{question | typed: typed, error: nil}
  def put_typed(question, _typed), do: question

  @doc """
  Whether the question is answered: it asks for no answer, or what was typed is its answer, the
  spaces around it left out.

      iex> MishkaGervaz.Question.answered?(%{answer: nil, typed: ""})
      true
      iex> MishkaGervaz.Question.answered?(%{answer: "Lamp", typed: " Lamp "})
      true
      iex> MishkaGervaz.Question.answered?(%{answer: "Lamp", typed: "lamp"})
      false
  """
  @spec answered?(map()) :: boolean()
  def answered?(%{answer: nil}), do: true
  def answered?(%{answer: answer, typed: typed}), do: String.trim(typed || "") == answer

  @doc "The question with the sentence that says its answer was not typed as it is written."
  @spec refuse(t()) :: t()
  def refuse(%{answer: answer} = question),
    do: %{
      question
      | error:
          dgettext("mishka_gervaz", "Type “%{answer}” exactly as it is written.", answer: answer)
    }

  @doc """
  Draws `question` in the UI adapter's `question/1` window, its events sent to `target`.

  ## Attributes
    * `:question` - the question, or `nil` to draw nothing
    * `:id` - the window's id
    * `:ui` - the UI adapter module
    * `:target` - the component its events go to (`@myself`)
  """
  attr :question, :map, default: nil
  attr :id, :string, required: true
  attr :ui, :atom, required: true
  attr :target, :any, default: nil

  @spec window(map()) :: Phoenix.LiveView.Rendered.t()
  def window(assigns) do
    ~H"""
    <.dynamic_component
      :if={@question}
      module={@ui}
      function={:question}
      id={@id}
      tone={@question.tone}
      title={@question.title}
      body={@question.body}
      answer={@question.answer}
      answer_label={@question.answer_label}
      typed={@question.typed}
      error={@question.error}
      confirm_label={@question.confirm_label}
      cancel_label={@question.cancel_label}
      on_confirm="question_confirm"
      on_change="question_typed"
      on_cancel="question_cancel"
      target={@target}
    />
    """
  end
end

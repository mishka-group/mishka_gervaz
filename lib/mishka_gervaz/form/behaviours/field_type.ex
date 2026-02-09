defmodule MishkaGervaz.Form.Behaviours.FieldType do
  @moduledoc """
  Behaviour for form field type renderers.

  Implement this behaviour to create custom field types that render
  form inputs in specific ways.

  ## Example

      defmodule MyApp.FieldTypes.Color do
        @behaviour MishkaGervaz.Form.Behaviours.FieldType
        use Phoenix.Component

        @impl true
        def render(assigns, config) do
          ~H\"\"\"
          <input type="color" name={@name} value={@value} />
          \"\"\"
        end

        @impl true
        def validate(value, _config), do: {:ok, value}

        @impl true
        def parse_params(value, _config), do: value

        @impl true
        def default_ui, do: %{type: :color}
      end

  Then use in DSL:

      field :background_color, MyApp.FieldTypes.Color
  """

  @doc """
  Render the form field input.

  ## Parameters

  - `assigns` - Phoenix assigns with field data
  - `config` - Field configuration map from DSL
  """
  @callback render(assigns :: map(), config :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Validate a field value.

  Returns `{:ok, value}` for valid values or `{:error, message}` for invalid.
  """
  @callback validate(value :: any(), config :: map()) :: {:ok, any()} | {:error, String.t()}

  @doc """
  Parse raw parameter value into the expected type.
  """
  @callback parse_params(raw_value :: any(), config :: map()) :: any()

  @doc """
  Return default UI configuration for this field type.
  """
  @callback default_ui() :: map()

  @optional_callbacks [validate: 2, parse_params: 2, default_ui: 0]
end

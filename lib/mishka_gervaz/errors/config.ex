defmodule MishkaGervaz.Errors.Config do
  @moduledoc """
  Runtime configuration errors.
  """
  use Splode.ErrorClass, class: :config

  defmodule MissingConfig do
    @moduledoc """
    Raised when required configuration is missing.

    ## Fields

    - `:resource` - The resource module
    - `:key` - The missing configuration key
    - `:config_path` - Optional path to the config
    """
    use Splode.Error, fields: [:resource, :key, :config_path], class: :config

    def message(%{resource: resource, key: key, config_path: nil}) do
      "Missing required config #{inspect(key)} for #{inspect(resource)}"
    end

    def message(%{resource: resource, key: key, config_path: config_path}) do
      "Missing required config #{inspect(key)} at #{inspect(config_path)} for #{inspect(resource)}"
    end
  end

  defmodule InvalidConfig do
    @moduledoc """
    Raised when configuration value is invalid.

    ## Fields

    - `:key` - The configuration key
    - `:value` - The invalid value
    - `:expected` - What was expected
    """
    use Splode.Error, fields: [:key, :value, :expected], class: :config

    def message(%{key: key, value: value, expected: expected}) do
      "Invalid config for #{inspect(key)}: got #{inspect(value)}, expected #{expected}"
    end
  end

  defmodule ModuleNotLoaded do
    @moduledoc """
    Raised when a required module is not loaded at runtime.

    ## Fields

    - `:module` - The module that's not loaded
    - `:purpose` - What the module is used for
    """
    use Splode.Error, fields: [:module, :purpose], class: :config

    def message(%{module: module, purpose: nil}) do
      "Module #{inspect(module)} is not loaded"
    end

    def message(%{module: module, purpose: purpose}) do
      "Module #{inspect(module)} (#{purpose}) is not loaded"
    end
  end

  defmodule PubSubError do
    @moduledoc """
    Raised when PubSub configuration or operation fails.

    ## Fields

    - `:pubsub` - The PubSub module
    - `:operation` - The operation that failed
    - `:reason` - The reason for the failure
    """
    use Splode.Error, fields: [:pubsub, :operation, :reason], class: :config

    def message(%{pubsub: pubsub, operation: op, reason: reason}) do
      "PubSub #{inspect(pubsub)} #{op} failed: #{inspect(reason)}"
    end
  end
end
